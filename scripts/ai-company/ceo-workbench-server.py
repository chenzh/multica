#!/usr/bin/env python3
"""Local CEO workbench API — portfolio status, queue, and dispatch."""

from __future__ import annotations

import json
import os
import re
import subprocess
import threading
import time
import uuid
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse

SCRIPT_DIR = Path(__file__).resolve().parent
MULTICA_ROOT = SCRIPT_DIR.parent.parent
WORKBENCH_DIR = SCRIPT_DIR / "workbench"
REGISTRY = Path(
    os.environ.get(
        "REGISTRY",
        MULTICA_ROOT / ".ai-company/templates/project-registry.yaml",
    )
)
GITHUB_ORG = os.environ.get("GITHUB_ORG", "chenzh")
JOBS_DIR = Path.home() / ".multica" / "ceo-workbench" / "jobs"
DEFAULT_PORT = int(os.environ.get("CEO_WORKBENCH_PORT", "9477"))

_jobs_lock = threading.Lock()
_jobs: dict[str, dict[str, Any]] = {}


@dataclass
class Project:
    id: str
    repo: str
    paused: bool = False
    priority: int = 0
    max_nightly_tickets: int = 1
    tier: str = ""
    notes: str = ""


def run_cmd(cmd: list[str], *, cwd: Path | None = None, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd or MULTICA_ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def parse_registry() -> list[Project]:
    if not REGISTRY.is_file():
        return []

    projects: list[Project] = []
    current: dict[str, Any] = {}
    for raw in REGISTRY.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("- id:"):
            if current.get("id"):
                projects.append(Project(**current))  # type: ignore[arg-type]
            current = {"id": line.split(":", 1)[1].strip()}
            continue
        for key in ("repo", "tier", "notes"):
            if line.startswith(f"{key}:"):
                current[key] = line.split(":", 1)[1].strip().strip('"')
        if line.startswith("paused:"):
            current["paused"] = line.split(":", 1)[1].strip() == "true"
        if line.startswith("priority:"):
            current["priority"] = int(line.split(":", 1)[1].strip())
        if line.startswith("max_nightly_tickets:"):
            current["max_nightly_tickets"] = int(line.split(":", 1)[1].strip())
    if current.get("id"):
        projects.append(Project(**current))  # type: ignore[arg-type]

    for project in projects:
        repo = project.repo
        repo = repo.removeprefix("github.com/").removeprefix("https://github.com/")
        if repo.startswith("your-org/"):
            repo = repo.replace("your-org/", f"{GITHUB_ORG}/", 1)
        project.repo = repo
    return projects


def cursor_agent_ready() -> bool:
    result = run_cmd(["cursor-agent", "status"], timeout=15)
    return result.returncode == 0 and "Logged in" in (result.stdout + result.stderr)


def multica_runtime_status() -> dict[str, Any]:
    result = run_cmd(
        ["bash", str(SCRIPT_DIR / "multica-runtime-status.sh"), "--json"],
        timeout=60,
    )
    if result.returncode != 0:
        return {"api_ok": False, "api_error": result.stderr.strip() or "multica-runtime-status failed"}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"api_ok": False, "api_error": "invalid JSON from multica-runtime-status"}


def resolve_repo_path(project_id: str = "", repo: str = "") -> str:
    cmd = ["bash", str(SCRIPT_DIR / "resolve-repo-path.sh"), "--quiet"]
    if project_id:
        cmd.extend(["--id", project_id])
    if repo:
        cmd.extend(["--repo", repo])
    result = run_cmd(cmd, timeout=30)
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def dashboard_rows() -> list[dict[str, Any]]:
    result = run_cmd(
        [
            "bash",
            str(SCRIPT_DIR / "ceo-dashboard.sh"),
            "--registry",
            str(REGISTRY),
            "--org",
            GITHUB_ORG,
            "--json",
        ],
        timeout=180,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "ceo-dashboard failed")

    rows: list[dict[str, Any]] = []
    registry = {p.id: p for p in parse_registry()}
    for line in result.stdout.splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        project = registry.get(row["id"])
        if project:
            row["local_path"] = resolve_repo_path(project.id, project.repo)
            row["local_path_resolved"] = bool(row["local_path"])
            row["priority"] = project.priority
            row["max_nightly_tickets"] = project.max_nightly_tickets
            row["tier"] = project.tier
            row["notes"] = project.notes
        rows.append(row)
    rows.sort(key=lambda item: item.get("priority", 0), reverse=True)
    return rows


def list_queue(repo: str) -> list[dict[str, Any]]:
    result = run_cmd(
        [
            "gh",
            "issue",
            "list",
            "-R",
            repo,
            "-l",
            "agent-safe",
            "-s",
            "open",
            "--json",
            "number,title,labels,url,updatedAt",
            "--jq",
            (
                '.[] | select([.labels[].name] | '
                '(index("agent-running") | not) and '
                '(index("agent-blocked") | not) and '
                '(index("agent-done") | not))'
            ),
        ],
        timeout=60,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "gh issue list failed")
    return json.loads(result.stdout or "[]")


def list_label(repo: str, label: str) -> list[dict[str, Any]]:
    result = run_cmd(
        [
            "gh",
            "issue",
            "list",
            "-R",
            repo,
            "-l",
            label,
            "-s",
            "open",
            "--json",
            "number,title,url,updatedAt",
        ],
        timeout=60,
    )
    if result.returncode != 0:
        return []
    return json.loads(result.stdout or "[]")


def save_job(job: dict[str, Any]) -> None:
    JOBS_DIR.mkdir(parents=True, exist_ok=True)
    path = JOBS_DIR / f"{job['id']}.json"
    path.write_text(json.dumps(job, indent=2), encoding="utf-8")


def load_jobs() -> list[dict[str, Any]]:
    if not JOBS_DIR.exists():
        return []
    jobs: list[dict[str, Any]] = []
    for path in sorted(JOBS_DIR.glob("*.json"), reverse=True):
        try:
            jobs.append(json.loads(path.read_text(encoding="utf-8")))
        except json.JSONDecodeError:
            continue
    return jobs[:20]


def start_dispatch_job(*, mode: str, repo: str = "", issue: str = "", max_total: int = 1, local_path: str = "") -> dict[str, Any]:
    job_id = uuid.uuid4().hex[:12]
    log_path = JOBS_DIR / f"{job_id}.log"
    JOBS_DIR.mkdir(parents=True, exist_ok=True)

    if mode == "portfolio":
        cmd = [
            "bash",
            str(SCRIPT_DIR / "portfolio-dispatch.sh"),
            "--registry",
            str(REGISTRY),
            "--max-total",
            str(max_total),
        ]
        if cursor_agent_ready():
            cmd.append("--local")
    elif mode == "issue":
        if not repo or not issue:
            raise ValueError("repo and issue are required")
        if not local_path:
            raise ValueError(f"local_path missing for {repo}")
        cmd = [
            "bash",
            str(SCRIPT_DIR / "../agent-delivery/dispatch-cursor-agent-cli.sh"),
            issue,
        ]
        env = os.environ.copy()
        env["GITHUB_REPOSITORY"] = repo
        env["REPO_ROOT"] = local_path
    else:
        raise ValueError(f"unknown mode: {mode}")

    with open(log_path, "w", encoding="utf-8") as log_file:
        if mode == "issue":
            proc = subprocess.Popen(
                cmd,
                cwd=MULTICA_ROOT,
                stdout=log_file,
                stderr=subprocess.STDOUT,
                env={**os.environ, "GITHUB_REPOSITORY": repo, "REPO_ROOT": local_path},
            )
        else:
            proc = subprocess.Popen(
                cmd,
                cwd=MULTICA_ROOT,
                stdout=log_file,
                stderr=subprocess.STDOUT,
            )

    job = {
        "id": job_id,
        "mode": mode,
        "repo": repo,
        "issue": issue,
        "max_total": max_total,
        "status": "running",
        "pid": proc.pid,
        "log_path": str(log_path),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "finished_at": None,
        "exit_code": None,
    }
    save_job(job)

    def watcher() -> None:
        code = proc.wait()
        job["status"] = "success" if code == 0 else "failed"
        job["exit_code"] = code
        job["finished_at"] = datetime.now(timezone.utc).isoformat()
        save_job(job)

    threading.Thread(target=watcher, daemon=True).start()
    return job


def start_site_factory_job(
    *,
    intake: str,
    create_repo: bool = False,
    notify: bool = True,
    max_dispatch: int = 2,
) -> dict[str, Any]:
    intake = intake.strip()
    if not intake:
        raise ValueError("intake is required")

    job_id = uuid.uuid4().hex[:12]
    log_path = JOBS_DIR / f"{job_id}.log"
    JOBS_DIR.mkdir(parents=True, exist_ok=True)

    cmd = [
        "bash",
        str(SCRIPT_DIR / "site-factory.sh"),
        "--intake",
        intake,
        "--max-dispatch",
        str(max_dispatch),
    ]
    if create_repo:
        cmd.extend(["--create-repo", "--push"])
    if notify:
        cmd.append("--notify")

    with open(log_path, "w", encoding="utf-8") as log_file:
        proc = subprocess.Popen(
            cmd,
            cwd=MULTICA_ROOT,
            stdout=log_file,
            stderr=subprocess.STDOUT,
        )

    job = {
        "id": job_id,
        "mode": "site-factory",
        "intake": intake,
        "create_repo": create_repo,
        "max_dispatch": max_dispatch,
        "status": "running",
        "pid": proc.pid,
        "log_path": str(log_path),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "finished_at": None,
        "exit_code": None,
    }
    save_job(job)

    def watcher() -> None:
        code = proc.wait()
        job["status"] = "success" if code == 0 else "failed"
        job["exit_code"] = code
        job["finished_at"] = datetime.now(timezone.utc).isoformat()
        save_job(job)

    threading.Thread(target=watcher, daemon=True).start()
    return job


def tail_log(path: str, lines: int = 40) -> str:
    file_path = Path(path)
    if not file_path.is_file():
        return ""
    content = file_path.read_text(encoding="utf-8", errors="replace").splitlines()
    return "\n".join(content[-lines:])


class Handler(BaseHTTPRequestHandler):
    server_version = "CEOWorkbench/0.1"

    def log_message(self, fmt: str, *args: Any) -> None:
        return

    def _send_json(self, status: int, payload: Any) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0:
            return {}
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path

        try:
            if path == "/api/health":
                self._send_json(HTTPStatus.OK, {"ok": True})
                return

            if path == "/api/meta":
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "org": GITHUB_ORG,
                        "registry": str(REGISTRY),
                        "cursor_agent_ready": cursor_agent_ready(),
                        "dispatch_mode": "local-cli" if cursor_agent_ready() else "gha",
                    },
                )
                return

            if path == "/api/multica-runtime":
                self._send_json(HTTPStatus.OK, multica_runtime_status())
                return

            if path == "/api/projects":
                rows = dashboard_rows()
                totals = {
                    "blocked": sum(int(row.get("blocked", 0)) for row in rows),
                    "running": sum(int(row.get("running", 0)) for row in rows),
                    "agent_safe": sum(int(row.get("agent_safe", 0)) for row in rows),
                    "merged_prs": sum(int(row.get("merged_prs", 0)) for row in rows),
                }
                self._send_json(HTTPStatus.OK, {"projects": rows, "totals": totals})
                return

            if path == "/api/queue":
                query = parse_qs(parsed.query)
                repo = query.get("repo", [""])[0]
                if not repo:
                    self._send_json(HTTPStatus.BAD_REQUEST, {"error": "repo is required"})
                    return
                queue = list_queue(repo)
                blocked = list_label(repo, "agent-blocked")
                running = list_label(repo, "agent-running")
                self._send_json(
                    HTTPStatus.OK,
                    {"repo": repo, "queue": queue, "blocked": blocked, "running": running},
                )
                return

            if path == "/api/jobs":
                self._send_json(HTTPStatus.OK, {"jobs": load_jobs()})
                return

            if path == "/api/site-factory":
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "ok": True,
                        "method": "POST",
                        "fields": ["intake", "create_repo", "notify", "max_dispatch"],
                    },
                )
                return

            match = re.fullmatch(r"/api/jobs/([a-f0-9]+)", path)
            if match:
                job_id = match.group(1)
                jobs = {job["id"]: job for job in load_jobs()}
                job = jobs.get(job_id)
                if not job:
                    self._send_json(HTTPStatus.NOT_FOUND, {"error": "job not found"})
                    return
                job = dict(job)
                job["log_tail"] = tail_log(job.get("log_path", ""))
                self._send_json(HTTPStatus.OK, job)
                return

            if path in ("/", "/index.html"):
                file_path = WORKBENCH_DIR / "index.html"
                content = file_path.read_bytes()
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(content)))
                self.end_headers()
                self.wfile.write(content)
                return

            for name in ("styles.css", "app.js"):
                if path == f"/{name}":
                    file_path = WORKBENCH_DIR / name
                    content = file_path.read_bytes()
                    content_type = "text/css" if name.endswith(".css") else "application/javascript"
                    self.send_response(HTTPStatus.OK)
                    self.send_header("Content-Type", f"{content_type}; charset=utf-8")
                    self.send_header("Content-Length", str(len(content)))
                    self.end_headers()
                    self.wfile.write(content)
                    return

            self._send_json(HTTPStatus.NOT_FOUND, {"error": "not found"})
        except Exception as exc:  # noqa: BLE001
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(exc)})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        try:
            if parsed.path == "/api/site-factory":
                body = self._read_json()
                intake = str(body.get("intake", "")).strip()
                if not intake:
                    self._send_json(HTTPStatus.BAD_REQUEST, {"error": "intake is required"})
                    return
                job = start_site_factory_job(
                    intake=intake,
                    create_repo=bool(body.get("create_repo", False)),
                    notify=body.get("notify", True) is not False,
                    max_dispatch=int(body.get("max_dispatch", 2)),
                )
                self._send_json(HTTPStatus.ACCEPTED, job)
                return

            if parsed.path != "/api/dispatch":
                self._send_json(HTTPStatus.NOT_FOUND, {"error": "not found"})
                return

            body = self._read_json()
            mode = body.get("mode", "portfolio")
            max_total = int(body.get("max_total", 1))
            repo = body.get("repo", "")
            issue = str(body.get("issue", ""))
            local_path = body.get("local_path", "")

            if not local_path and repo:
                project_id = ""
                for project in parse_registry():
                    if project.repo == repo:
                        project_id = project.id
                        break
                local_path = resolve_repo_path(project_id, repo)

            job = start_dispatch_job(
                mode=mode,
                repo=repo,
                issue=issue,
                max_total=max_total,
                local_path=local_path,
            )
            self._send_json(HTTPStatus.ACCEPTED, job)
        except ValueError as exc:
            self._send_json(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
        except Exception as exc:  # noqa: BLE001
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(exc)})


def main() -> None:
    host = os.environ.get("CEO_WORKBENCH_HOST", "127.0.0.1")
    port = DEFAULT_PORT
    server = ThreadingHTTPServer((host, port), Handler)
    print(f"CEO workbench: http://{host}:{port}")
    print("Press Ctrl+C to stop.")
    server.serve_forever()


if __name__ == "__main__":
    main()
