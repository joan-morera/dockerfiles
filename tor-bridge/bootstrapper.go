package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"
	"syscall"
)

func main() {
	nick := os.Getenv("NICKNAME")
	if nick == "" {
		nick = "DockerObfs4Bridge"
	}

	orPort := os.Getenv("OR_PORT")
	ptPort := os.Getenv("PT_PORT")
	email := os.Getenv("EMAIL")

	fmt.Printf("Using NICKNAME=%s, OR_PORT=%s, PT_PORT=%s, and EMAIL=%s.\n", nick, orPort, ptPort, email)

	var additionalVariables strings.Builder
	if os.Getenv("OBFS4_ENABLE_ADDITIONAL_VARIABLES") == "1" {
		fmt.Println("Additional properties from 'OBFS4V_' environment variables processing enabled")
		for _, e := range os.Environ() {
			if strings.HasPrefix(e, "OBFS4V_") {
				pair := strings.SplitN(e, "=", 2)
				if len(pair) == 2 {
					key := strings.TrimPrefix(pair[0], "OBFS4V_")
					value := pair[1]
					fmt.Printf("Overriding '%s' with value '%s'\n", key, value)
					additionalVariables.WriteString(fmt.Sprintf("%s %s\n", key, value))
				}
			}
		}
	}

	torrcContent := fmt.Sprintf(`RunAsDaemon 0
SocksPort 0
BridgeRelay 1
Nickname %s
Log notice stdout
ServerTransportPlugin obfs4 exec /usr/bin/lyrebird
ExtORPort auto
DataDirectory /var/lib/tor
ORPort %s
ServerTransportListenAddr obfs4 0.0.0.0:%s
ContactInfo %s
%s
`, nick, orPort, ptPort, email, additionalVariables.String())

	err := ioutil.WriteFile("/etc/tor/torrc", []byte(torrcContent), 0644)
	if err != nil {
		log.Fatalf("Failed to write torrc: %v", err)
	}

	fmt.Println("Starting tor.")
	torPath, err := exec.LookPath("tor")
	if err != nil {
		log.Fatalf("Failed to find tor binary: %v", err)
	}

	args := []string{"tor", "-f", "/etc/tor/torrc"}
	if err := syscall.Exec(torPath, args, os.Environ()); err != nil {
		log.Fatalf("Failed to exec tor: %v", err)
	}
}
