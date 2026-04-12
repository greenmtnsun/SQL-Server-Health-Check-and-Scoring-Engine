# SQL-Server-Health-Check-and-Scoring-Engine

> Measure SQL Server health — don’t just list problems.

SQL-Server-Health-Check-and-Scoring-Engine is a modular PowerShell framework that evaluates SQL Server operational health using a **scoring-based model** instead of static checklists.

It collects signals across important operational domains, assigns weighted scores, and produces a unified health score with actionable output.

---

## Why this exists

Most SQL Server health check tools:
- dump long lists of findings
- do not prioritize what matters
- do not compare against a baseline
- do not help reduce accepted noise

This project is built to solve that.

It provides:

- **Weighted scoring engine**
- **Baseline comparison**
- **HTML and JSON reports**
- **Policy-based ignore rules**
- **Extensible collector model**
- **Fleet rollup potential across multiple instances**

---

## Core idea

Instead of just asking:

> What findings exist?

This tool asks:

> How healthy is this SQL Server overall, what is dragging the score down, and what changed since last time?

---

## Features

- SQL Server health checks across multiple operational domains
- Weighted findings and domain-level scoring
- Overall score generation
- Baseline comparison for drift/regression detection
- Policy-based suppression of accepted findings
- HTML report for human review
- JSON output for automation and future integrations
- Modular collector architecture

---

## Example output

Example summary:

- Overall Score: **94.8**
- Warning Count: **4**
- Ignored Count: **0**

Example domain scores:

- Backups: **90**
- Performance: **94.5**
- ErrorLog: **70**

---

## Project structure

```text
SQL-Server-Health-Check-and-Scoring-Engine/
│
├── Config/
├── Private/
│   ├── Core/
│   └── Collectors/
├── Public/
├── SqlTechnicalSanity.psd1
├── SqlTechnicalSanity.psm1
├── Example-Run.ps1
└── README.md
