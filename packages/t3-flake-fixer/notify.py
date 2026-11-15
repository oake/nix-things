import json
from pathlib import Path
from urllib.request import Request, urlopen


def notify(context, url):
    value = json.loads(Path(context).read_text())
    build = value.get("build", {})
    repo = value["repository"]
    if (
        build.get("status") != "failed"
        or build.get("branch") != "flake-update"
        or value.get("pullRequest")
    ):
        return
    revision = build["rev"]
    author = build.get("author")
    if author != "github-actions[bot] <github-actions[bot]@users.noreply.github.com>":
        return
    failures = [
        dict(
            type="evaluation" if item["status"] == "failed_eval" else "build",
            attribute=item["attr"],
        )
        for item in build.get("compilationFailures", [])
    ]
    if build.get("evaluationError"):
        failures.append(dict(type="parent_evaluation", attribute=None))
    if not failures:
        return
    payload = dict(
        repository=repo,
        revision=revision,
        build_id=build["id"],
        build_number=build["number"],
        failed_attributes=failures,
    )
    request = Request(
        url,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urlopen(request, timeout=60) as response:
        response.read()
