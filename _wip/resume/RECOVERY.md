# Resume UI recovery checkpoint

Recovered from this runtime agent's own earlier code-writing tool calls, then SHA-256 compared against hashes printed before the cloud outage. No restricted session files read.

- `main.gd`: f4768bae8bedcae981afa1c25051acd23b16d31c7af741b1a7ff15415372c93f — byte-identical to 13:11 pre-outage snapshot.
- `resume_controller.gd`: fecc26a2c27bbe3bdf569efb4e22b4084b167dfa08b8effe93b7ec07a9bda862 — byte-identical to same snapshot.
- `rebuild_main.py`: deterministic isolated reconstruction from pre-resume main SHA417544c6b1f43914bc8f83524d9037e073a7c84cb5ea9ac04cc7971dd0534e41. Does not write production.

Both known corrected defects are included: canceling initial reader visibly pauses saves; externally changed checkpoint tokens clear resumable candidate while retaining only an explicitly non-guaranteed reference summary.

This is recovery evidence, NOT fresh test acceptance. The 13:12 full-204 regression was interrupted and has no terminal pass. All integration, independent audit, graphical, restart, font and complete-rule regressions must rerun after restoration. Historical 13 self-checks / earlier native observations are not current passes.

Production is not modified by this recovery directory. Codec/store are being recovered separately by their original author and must match their respective frozen hashes before use.
