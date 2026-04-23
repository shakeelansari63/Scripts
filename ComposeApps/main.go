package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Method to get Current Running Dir
func getRunningDir() (string, error) {
	// Get Executable Path
	execPath, err := os.Executable()

	// Error handle
	if err != nil {
		return "", errors.New("Cannot read Executable file path")
	}

	// Get Directory
	execDir := filepath.Dir(execPath)

	return execDir, nil
}

// Get List of ymls in Running Dir
func getAppYamls() (map[string]string, error) {
	// Get Running Dir
	runningDir, err := getRunningDir()
	if err != nil {
		return nil, err
	}

	// Get List of Files in Directory
	files, err := filepath.Glob(runningDir + "/*.yml")
	if err != nil {
		return nil, err
	}

	// Generate Map of App name and Yaml Path
	apps := make(map[string]string)

	for _, yamlFile := range files {
		// File name from full path
		fileName := filepath.Base(yamlFile)
		appName := strings.TrimSuffix(fileName, ".yml")

		// Add App to Map
		apps[appName] = yamlFile
	}

	return apps, nil
}

func main() {
	// Get all yamls
	appYamls, err := getAppYamls()
	if err != nil {
		panic(err)
	}

	for app, yaml := range appYamls {
		fmt.Println(app, yaml)
	}
}
