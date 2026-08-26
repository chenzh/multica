const state = {
  projects: [],
  totals: {},
  selectedRepo: "",
  selectedProject: null,
  meta: {},
  jobs: [],
  pollTimer: null,
};

async function api(path, options = {}) {
  const response = await fetch(path, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || `Request failed: ${response.status}`);
  }
  return data;
}

function statusClass(project) {
  if (!project.accessible) return "muted";
  if (Number(project.blocked) > 0) return "bad";
  if (project.paused === true || project.paused === "true") return "warn";
  return "good";
}

function formatTotals() {
  document.getElementById("metric-blocked").textContent = state.totals.blocked ?? 0;
  document.getElementById("metric-running").textContent = state.totals.running ?? 0;
  document.getElementById("metric-queue").textContent = state.totals.agent_safe ?? 0;
  document.getElementById("metric-merged").textContent = state.totals.merged_prs ?? 0;
}

function renderProjects() {
  const tbody = document.getElementById("projects-body");
  tbody.innerHTML = "";

  for (const project of state.projects) {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>
        <div class="project-name">
          <span class="status-dot ${statusClass(project)}"></span>${project.id}
        </div>
        <div class="project-repo">${project.repo}</div>
      </td>
      <td>${project.blocked}</td>
      <td>${project.running}</td>
      <td>${project.agent_safe}</td>
      <td>
        <button data-repo="${project.repo}" class="view-queue">看队列</button>
      </td>
    `;
    tbody.appendChild(tr);
  }

  document.querySelectorAll(".view-queue").forEach((button) => {
    button.addEventListener("click", () => {
      const repo = button.getAttribute("data-repo");
      const project = state.projects.find((item) => item.repo === repo);
      selectProject(project);
    });
  });

  if (!state.selectedRepo && state.projects.length > 0) {
    const first = state.projects.find((item) => item.accessible && item.paused !== true && item.paused !== "true");
    if (first) selectProject(first);
  }
}

function renderMeta() {
  const pill = document.getElementById("dispatch-mode");
  const ready = state.meta.cursor_agent_ready;
  pill.textContent = ready ? "本地 cursor-agent 已登录" : "未登录 cursor-agent";
  pill.className = `pill ${ready ? "good" : "warn"}`;
  document.getElementById("org-label").textContent = `org: ${state.meta.org || "-"}`;
}

async function selectProject(project) {
  if (!project) return;
  state.selectedRepo = project.repo;
  state.selectedProject = project;
  document.getElementById("queue-title").textContent = `${project.id} 队列`;
  document.getElementById("dispatch-one").disabled = !project.local_path;
  const hint = document.getElementById("path-hint");
  if (hint) {
    hint.textContent = project.local_path
      ? `本地路径: ${project.local_path}`
      : "未找到本地 checkout — 在 .ai-company/config/local.env 配置 AI_REPO_PATH_* 或 MUSIC_SAAS_PATH";
  }
  await loadQueue();
}

async function loadQueue() {
  if (!state.selectedRepo) return;
  const panel = document.getElementById("queue-panel");
  panel.innerHTML = `<div class="empty">加载中…</div>`;
  const data = await api(`/api/queue?repo=${encodeURIComponent(state.selectedRepo)}`);
  const sections = [
    ["可派单", data.queue, true],
    ["运行中", data.running, false],
    ["阻塞", data.blocked, false],
  ];

  panel.innerHTML = "";
  for (const [title, items, canDispatch] of sections) {
    const block = document.createElement("div");
    block.innerHTML = `<h3>${title} (${items.length})</h3>`;
    if (items.length === 0) {
      block.innerHTML += `<div class="empty">无</div>`;
    } else {
      const list = document.createElement("ul");
      list.className = "issue-list";
      for (const issue of items) {
        const li = document.createElement("li");
        li.className = "issue-item";
        li.innerHTML = `
          <div class="issue-title">#${issue.number} ${issue.title}</div>
          <div class="issue-meta">${issue.url}</div>
          <div class="issue-actions">
            <a href="${issue.url}" target="_blank" rel="noreferrer">打开 Issue</a>
            ${
              canDispatch
                ? `<button class="dispatch-issue" data-issue="${issue.number}">派这一单</button>`
                : ""
            }
          </div>
        `;
        list.appendChild(li);
      }
      block.appendChild(list);
    }
    panel.appendChild(block);
  }

  document.querySelectorAll(".dispatch-issue").forEach((button) => {
    button.addEventListener("click", async () => {
      const issue = button.getAttribute("data-issue");
      await dispatchIssue(issue);
    });
  });
}

async function loadProjects() {
  const data = await api("/api/projects");
  state.projects = data.projects;
  state.totals = data.totals;
  formatTotals();
  renderProjects();
}

async function loadMeta() {
  state.meta = await api("/api/meta");
  renderMeta();
}

async function loadJobs() {
  const data = await api("/api/jobs");
  state.jobs = data.jobs;
  const container = document.getElementById("jobs-panel");
  if (!state.jobs.length) {
    container.innerHTML = `<div class="empty">暂无派单任务</div>`;
    return;
  }

  container.innerHTML = state.jobs
    .map(
      (job) => `
      <div class="job-item" data-job="${job.id}">
        <div><strong>${job.mode}</strong> ${job.repo || "portfolio"} ${job.issue ? `#${job.issue}` : ""}</div>
        <div class="job-status">${job.status} · ${job.started_at || ""}</div>
        <button class="view-log" data-job="${job.id}">看日志</button>
      </div>
    `
    )
    .join("");

  document.querySelectorAll(".view-log").forEach((button) => {
    button.addEventListener("click", async () => {
      const jobId = button.getAttribute("data-job");
      const job = await api(`/api/jobs/${jobId}`);
      document.getElementById("log-box").textContent = job.log_tail || "(empty)";
    });
  });
}

async function dispatchPortfolio(maxTotal) {
  const job = await api("/api/dispatch", {
    method: "POST",
    body: JSON.stringify({ mode: "portfolio", max_total: maxTotal }),
  });
  await refreshAll();
  document.getElementById("log-box").textContent = `Started job ${job.id}\n${job.log_path || ""}`;
}

async function dispatchIssue(issue) {
  const project = state.selectedProject;
  if (!project?.local_path) {
    alert("未找到本地 checkout。在 .ai-company/config/local.env 设置 AI_REPO_PATH_* 或 MUSIC_SAAS_PATH，或把仓库放在 ~/Projects / ~/Desktop 下让系统自动发现。");
    return;
  }
  const job = await api("/api/dispatch", {
    method: "POST",
    body: JSON.stringify({
      mode: "issue",
      repo: project.repo,
      issue,
      local_path: project.local_path,
    }),
  });
  await refreshAll();
  document.getElementById("log-box").textContent = `Started job ${job.id}\n${job.log_path || ""}`;
}

async function refreshAll() {
  await Promise.all([loadMeta(), loadProjects(), loadJobs()]);
  if (state.selectedRepo) await loadQueue();
}

function bindEvents() {
  document.getElementById("refresh-btn").addEventListener("click", refreshAll);
  document.getElementById("dispatch-portfolio").addEventListener("click", async () => {
    const maxTotal = Number(document.getElementById("max-total").value || "1");
    await dispatchPortfolio(maxTotal);
  });
  document.getElementById("dispatch-one").addEventListener("click", async () => {
    const data = await api(`/api/queue?repo=${encodeURIComponent(state.selectedRepo)}`);
    if (!data.queue?.length) {
      alert("当前没有可派 issue。");
      return;
    }
    await dispatchIssue(String(data.queue[0].number));
  });
}

async function main() {
  bindEvents();
  await refreshAll();
  state.pollTimer = window.setInterval(loadJobs, 5000);
}

main().catch((error) => {
  document.body.innerHTML = `<pre style="padding:24px;color:#ff6b6b;">${error.message}</pre>`;
});
