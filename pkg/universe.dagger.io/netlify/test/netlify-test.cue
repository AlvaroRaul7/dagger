package yarn

import (
	"dagger.io/dagger"
	"dagger.io/dagger/engine"

	"universe.dagger.io/netlify"
	"universe.dagger.io/alpine"
	"universe.dagger.io/bash"
)

dagger.#Plan & {
	inputs: secrets: test: command: {
		name: "sops"
		args: ["-d", "../../test_secrets.yaml"]
	}

	actions: {
		testSecrets: dagger.#DecodeSecret & {
			input:  inputs.secrets.test.contents
			format: "yaml"
		}

		marker: "hello world"

		data: engine.#WriteFile & {
			input:    engine.#Scratch
			path:     "index.html"
			contents: marker
		}

		// Deploy to netlify
		deploy: netlify.#Deploy & {
			team:  "blocklayer"
			token: testSecrets.output.netlifyToken.contents

			site:     "dagger-test"
			contents: data.output
		}

		image: alpine.#Build & {
			packages: {
				bash: {}
				curl: {}
			}
		}

		// Check if the website was deployed
		verify: bash.#Run & {
			input: image.output
			script: contents: #"""
			  test "$(curl \#(deploy.deployUrl))" = "\#(marker)"
			  """#
		}
	}
}