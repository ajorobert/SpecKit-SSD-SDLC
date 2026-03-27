# sk.clarify
Wraps: upstream.clarify
Thin wrapper — upstream handles all clarification logic.

## Pre-flight
1. Verify state.yaml has active_story set
   - NULL → STOP, instruct user to run sk.specify first

## Execute upstream clarify
Read upstream.clarify from upstream-adapter.md
Execute upstream clarify instructions in full

## Post-execution
If clarification changes scope or introduces new constraints:
- Flag to user that sk.specify may need updating
- Suggest re-running checkpoint classification
