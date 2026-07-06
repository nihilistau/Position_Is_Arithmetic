import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from harness.skills.builtin.coding import read_file, write_file, edit_file, search, run_tests, run_command
from harness.mcp.tools import ToolSpec
ts = [ToolSpec.from_callable(f) for f in (read_file, write_file, edit_file, search, run_tests, run_command)]
print("TOOLS_OK", len(ts), [t.name for t in ts])
# also confirm run_task default path builds its toolset without a client call
import harness.control.task_loop as tl
print("IMPORT_OK", hasattr(tl, "run_task"), hasattr(tl, "post_task"), hasattr(tl, "advance_pending_task"))
