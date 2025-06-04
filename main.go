package main

import (
	"bufio"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

var (
	outputDir = flag.String("output", "", "Required: output directory to store built images")
	syncFrom  = flag.String("sync_from", "", "Optional: import Nix store from this directory")
	syncTo    = flag.String("sync_to", "", "Optional: export Nix store to this directory")
	buildMtx  = sync.Mutex{}
)

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer func() {
		if cerr := out.Close(); err == nil {
			err = cerr
		}
	}()

	_, err = io.Copy(out, in)
	return err
}

func buildSystemToplevel() (string, error) {
	cmd := exec.Command("nix", "build", "--no-link", "--impure", ".#nixosConfigurations.default.config.system.build.toplevel")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return "", err
	}

	evalCmd := exec.Command("nix", "eval", "--raw", "--impure", ".#nixosConfigurations.default.config.system.build.toplevel")
	var out bytes.Buffer
	evalCmd.Stdout = &out
	evalCmd.Stderr = os.Stderr
	if err := evalCmd.Run(); err != nil {
		return "", err
	}
	return strings.TrimSpace(out.String()), nil
}

func buildFlakeOutput(attr string) (string, error) {
	cmd := exec.Command("nix", "build", "--no-link", "--print-out-paths", ".#"+attr)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return "", err
	}
	return strings.TrimSpace(out.String()), nil
}

func getRuntimePaths(path string) ([]string, error) {
	cmd := exec.Command("nix", "path-info", "-r", path)
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return nil, err
	}

	var paths []string
	scanner := bufio.NewScanner(&out)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			paths = append(paths, line)
		}
	}
	return paths, nil
}

func copyPathsFromStore(store string) error {
	cmd := exec.Command("nix", "copy", "--all", "--no-check-sigs", "--from", "file://"+store)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func copyPathsToStore(paths []string, store string) error {
	args := []string{"copy", "--to", "file://" + store}
	args = append(args, paths...)
	cmd := exec.Command("nix", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func createImage(w http.ResponseWriter, r *http.Request) {
	start := time.Now()

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	cfg, err := io.ReadAll(r.Body)
	if err != nil || len(cfg) == 0 {
		http.Error(w, "Provide a valid config", http.StatusBadRequest)
		return
	}

	hash := sha256.Sum256(cfg)
	sum := hex.EncodeToString(hash[:])
	destFile := filepath.Join(*outputDir, sum+".qcow2")

	if _, err = os.Stat(destFile); err == nil {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, `{"filename": "%s.qcow2"}`, sum)
		log.Printf("Done after %.2f seconds (cache hit)\n", time.Since(start).Seconds())
		return
	}

	buildMtx.Lock()
	defer buildMtx.Unlock()

	if err = os.WriteFile("/tmp/machine-config.nix", cfg, 0600); err != nil {
		log.Println("Write config error:", err)
		http.Error(w, "Server error", http.StatusInternalServerError)
		return
	}

	if *syncFrom != "" {
		log.Println("Syncing from store:", *syncFrom)
		if err := copyPathsFromStore(*syncFrom); err != nil {
			log.Println("Failed to sync from store:", err)
		}
	}

	log.Println("Evaluating system.build.toplevel...")

	path, err := buildSystemToplevel()
	if err != nil {
		log.Println("Evaluation failed:", err)
		http.Error(w, "Evaluation failed", http.StatusInternalServerError)
		return
	}

	runtimePaths, err := getRuntimePaths(path)
	if err != nil {
		log.Println("Failed to get runtime paths:", err)
		http.Error(w, "Path-info failed", http.StatusInternalServerError)
		return
	}

	if *syncTo != "" {
		log.Println("Syncing runtime paths to store:", *syncTo)
		emulationPath, err := buildFlakeOutput("emulationPackages")
		if err != nil {
			log.Println("Failed to build emulationPackages:", err)
			http.Error(w, "Build emulationPackages failed", http.StatusInternalServerError)
			return
		}

		runtimePaths = append(runtimePaths, emulationPath)
		if err := copyPathsToStore(runtimePaths, *syncTo); err != nil {
			log.Println("Failed to sync to store:", err)
			http.Error(w, "Copy to store failed", http.StatusInternalServerError)
			return
		}
	}

	log.Println("Building vmImage", sum)

	buildOutput := &bytes.Buffer{}
	buildCmd := exec.Command("nix", "build", "--no-link", "--print-out-paths", "--impure", ".#vmImage")
	buildCmd.Stdout = buildOutput
	buildCmd.Stderr = os.Stderr

	if err := buildCmd.Run(); err != nil {
		log.Println("Build failed:", err)
		http.Error(w, "Build failed", http.StatusInternalServerError)
		return
	}

	builtPath := strings.TrimSpace(buildOutput.String())
	srcPath := filepath.Join(builtPath, "nixos.qcow2")

	if err = copyFile(srcPath, destFile); err != nil {
		log.Println("Copy error:", err)
		http.Error(w, "Failed to copy output", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	fmt.Fprintf(w, `{"filename": "%s.qcow2"}`, sum)
	log.Printf("Done after %.2f seconds (build success)\n", time.Since(start).Seconds())
}

func main() {
	flag.Parse()

	if *outputDir == "" {
		log.Fatal("Missing required --output argument")
	}

	if err := os.MkdirAll(*outputDir, 0755); err != nil {
		log.Fatalf("Failed to create output directory: %v", err)
	}

	http.HandleFunc("/", createImage)
	log.Println("Starting server on :8080...")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal("Error starting server:", err)
	}
}
