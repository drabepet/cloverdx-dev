# CloverDX Architecture Reference

## Table of Contents
1. Dual JVM Model
2. Network Ports
3. Memory Sizing
4. Storage Strategy
5. Deployment Options
6. AWS Marketplace
7. Cluster Configuration
8. Wrangler Workspaces

---

## 1. Dual JVM Model

CloverDX Server runs two separate JVM processes:

**Core JVM** — Manages scheduling, web UI, REST API, user management, cluster coordination.
Lightweight (target below 10% CPU). Core failure = loss of admin control and scheduling.
Running Worker jobs are NOT killed by a Core restart.

**Worker JVM** — Executes all graph/jobflow transformations in isolation. Restarts
independently if it crashes (e.g., OOM). Worker failure = data throughput interruption only;
Server console and API remain available. Each Core node has exactly one Worker.

**Cluster** — Multiple Core+Worker pairs sharing a single system database. Active-active,
no master/slave. Job execution is load-balanced across nodes.

**Diagnostic implication:** Monitor Core and Worker separately. Worker restarts are expected
recovery events. A Core restart mid-day warrants investigation.

**Current production version:** 7.3.1
- Requires Tomcat 10.1 (Jakarta EE — mandatory for 7.x; Tomcat 9.x is NOT supported)
- Java 17 (Eclipse Temurin recommended)

---

## 2. Network Ports — Complete Reference

| Protocol | Port | Purpose | Notes |
|---|---|---|---|
| HTTP/HTTPS | 8080/8443 (or 80/443 via proxy) | Server Console, REST API, Designer | Primary entry point |
| JGroups | 7800 | Cluster inter-node messaging and health | Required for cluster state sync and failover |
| Worker gRPC | 10500-10600 | Core-Worker data pipe | Job output streams and activity requests |
| Cluster gRPC | 10600 | Synchronous inter-node comms | Remote Edge data transfer across cluster nodes |
| JMX | 8686 | JVM metrics (heap, threads, active jobs) | Restrict to trusted IPs in production |

**Critical:** gRPC ports 10500-10600 must be open between all cluster nodes. If blocked,
Remote Edge failures force data through intermediate storage — performance degrades by
orders of magnitude.

---

## 3. Memory Sizing — The 75% Rule

Combined max heap (Xmx) of Core + Worker must not exceed 75% of total RAM.
Remaining 25% covers OS, JDBC direct memory, and JVM Metaspace.

**Formula:** `Xmx_Core + Xmx_Worker <= 0.75 × RAM_total`

| Instance | RAM | Max Core Heap | Max Worker Heap | OS/Non-Heap |
|---|---|---|---|---|
| m6i.xlarge | 16 GB | 4 GB | 7 GB | 5 GB |
| m6i.2xlarge | 32 GB | 7 GB | 15 GB | 10 GB |
| m6i.4xlarge | 64 GB | 8 GB | 40 GB | 16 GB |
| m6i.8xlarge | 128 GB | 8 GB | 95 GB | 25 GB |

**Key principle:** Cap Core at 8 GB even on large instances. Core responsibilities don't
scale linearly with memory. Excessive Core heap increases GC pause duration. Always give
surplus RAM to the Worker or OS disk cache.

**Config:** Set Worker heap via one of:
- Setup GUI: Configuration → Setup → Worker → Maximum heap size (recommended)
- `clover.properties`: `worker.jvmOptions=-Xmx<size>m -Xms<initsize>m`
- Docker env var: `CLOVER_WORKER_HEAP_SIZE=<size_in_MB>`

**Alert threshold:** Alarm when combined heap consistently exceeds 80%. Monitor `cHeap`
(Core) and `wHeap` (Worker) from the 3-second performance log.

---

## 4. Storage Strategy

Three logical storage areas — mixing them on one volume is a common mistake:

| Area | Location | Recommendation |
|---|---|---|
| Project sandboxes/artifacts | /var/clover/sandboxes | gp3, 200+ GB, 3000 IOPS baseline |
| Server and Tomcat logs | /var/clover/cloverlogs | gp3, 50+ GB |
| Temp / spill-to-disk | java.io.tmpdir | Dedicated separate volume |

**Spill-to-disk:** ExtSort and ExtHashJoin write temp files when Worker heap is exhausted.
If temp shares a volume with sandboxes/logs, a large sort saturates the volume and can
freeze the Server UI. Always use a separate temp volume.

**EBS encryption:** Mandatory for production — AES-256 via AWS KMS.

---

## 5. Deployment Options

| Mode | Use Case |
|---|---|
| Single-node | Dev, test, small production workloads |
| Clustered (2-N nodes) | HA, horizontal scaling, load distribution |
| On-premise | Full control, air-gapped, regulated industries |
| Cloud IaaS | AWS EC2, Azure VMs, GCP Compute |
| Kubernetes/Docker | Supported via github.com/cloverdx/cloverdx-server-docker |
| Embedded | CloverDX engine in a Java application (no Server) |

**Supported OS:** Ubuntu 22/24 LTS, RHEL 9. Windows Server is non-production only.
**App servers:** Tomcat 10.1.x (most common), Red Hat JBoss Web Server 6.0.
**System databases:** PostgreSQL 15 (recommended), MySQL 8, Oracle 23, SQL Server 2022.

---

## 6. AWS Marketplace Deployment

BYOL offering via CloudFormation. Two templates:
- **New VPC:** Creates all networking. Good for greenfield.
- **Existing VPC:** Deploys into pre-existing network. Recommended for enterprise.

Stack provisions: EC2 (Ubuntu 24.04, Tomcat 10.1, Java 17) + RDS PostgreSQL (two AZs) +
EBS gp3 + IAM roles (least-privilege S3 and Secrets Manager access).

**Upgrades:** Use the dedicated Upgrade CloudFormation Template — it snapshots RDS and EBS,
launches new EC2 from new AMI, reconnects to snapshotted database.

---

## 7. Cluster Configuration

- **Load balancing:** CPU-weighted + memory-weighted (`cluster.lb.cpu.weight`,
  `cluster.lb.memory.weight`, exponents configurable)
- **Job queue:** Max 100,000 jobs default; backpressure via heap and CPU thresholds
- **Concurrent jobs:** Configuration → Setup → Worker → "Maximum jobs running concurrently"

---

## 8. Wrangler Workspaces (7.3+)

- **Private Workspace** (`wrangler_home__[username]`): Isolated draft sandbox per user
- **Shared Workspace** (`wrangler_shared_home`): Team collaboration sandbox
- **Roles:** Viewer (read-only) vs Editor (full modify)

**Infrastructure impact:** Every Wrangler step triggers a partial execution on the Worker.
Multiple simultaneous users create cumulative load. Scale Worker heap proportionally
(Configuration → Setup → Worker → Maximum heap size).

**Licensing:** Each active private workspace consumes a Wrangler Seat. Exceeding licensed
seats disables data previews and job execution.
