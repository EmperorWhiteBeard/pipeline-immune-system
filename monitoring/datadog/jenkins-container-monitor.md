# Jenkins Container Monitor (Datadog)

Monitors the Jenkins container's up/down state via the Datadog Agent and alerts
to Slack on failure/recovery.

## Setup

**Datadog Agent** runs as a Docker container on the host, mounting Docker
socket, proc, cgroup, and container log paths for host + container metrics:

```bash
docker run -d --name dd-agent \
  -e DD_API_KEY=<your_api_key> \
  -e DD_SITE="us5.datadoghq.com" \
  -e DD_DOGSTATSD_NON_LOCAL_TRAFFIC=true \
  -e DD_ENV=sentinelops-demo \
  -e DD_KUBERNETES_KUBELET_HOST=<EC2_PRIVATE_IP> \
  -e DD_KUBELET_TLS_VERIFY=false \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /proc/:/host/proc/:ro \
  -v /sys/fs/cgroup/:/host/sys/fs/cgroup:ro \
  -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
  -v /var/lib/kubelet:/var/lib/kubelet:ro \
  registry.datadoghq.com/agent:7
```

## Monitor config

- **Metric:** `docker.containers.running{short_image:jenkins}`
- **Detection method:** Threshold Alert
- **Evaluation:** average over a 1-minute rolling window
- **Alert condition:** trigger when value is below `1` (i.e., 0 containers running)
- **Missing data:** show last known status after 1 minute

> Note: initial attempts scoped the monitor to `container_name:jenkins` on the
> `docker.service_up` **service check**, but that check only reports host-level
> Docker daemon health (one result per host, no `container_name` tag) — not
> per-container status. Switched to a **metric monitor** on
> `docker.containers.running` scoped by `short_image:jenkins`, which does carry
> per-container tags.
>
> The evaluation window was also shortened from 5 minutes to 1 minute average,
> since a 5-minute rolling average was slow to react to short container
> restarts during testing.

## Slack integration

- Datadog Slack app installed into the `SentinelOps` workspace, `#devops-alerts` channel added under Integrations → Slack → Channels.
- Monitor message includes `@slack-devops-alerts` as the notification recipient (must be typed as one token — the mention picker UI didn't reliably surface the channel by default).

## Message template
{{#is_alert}}
🚨 Jenkins container is not running on {{host.name}}. Check with: docker ps -a | grep jenkins
{{/is_alert}}

{{#is_recovery}}
✅ Jenkins container is back up on {{host.name}}.
{{/is_recovery}}

@slack-devops-alerts
## Status

- [x] Metric monitor created and scoped correctly
- [x] Slack channel connected and recipient resolved in monitor message
- [ ] End-to-end alert fire/recovery verified via live stop/start test
