# Wire the DAST gate into pipeline.yml

Add a `dast` job to your orchestrator `.github/workflows/pipeline.yml`, and add it
to the terminal `pipeline-status` job's `needs:` list so it BLOCKS.

## 1. Add the job (alongside your other reusable-gate jobs)

  dast:
    name: Ephemeral DAST
    needs: [iac-scan]          # run after IaC passes; adjust to your DAG
    uses: ./.github/workflows/reusable-dast.yml
    with:
      target_service: payments-api
      target_port: 8001

## 2. Make it blocking — add `dast` to the terminal gate's needs

  pipeline-status:
    name: Pipeline Status (fail-closed)
    needs: [secret-scan, sast, sca, iac-scan, dast, supply-chain]   # <-- add dast
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Fail if any gate failed
        run: |
          if echo "${{ join(needs.*.result, ' ') }}" | grep -qvE '^(success ?)+$'; then
            echo "::error::One or more gates failed."; exit 1
          fi
          echo "All gates passed."

(Use your existing pipeline-status logic; the key change is adding `dast` to needs.)
