# Changelog

## Unreleased

- Draft RDS MySQL MultiNode and DoubleNode module with explicit network ownership, sensitive administrator input, replica topology, running-instance backup policy and parameter templates.
- Remove unsupported online Handler controls for backup public download, retention after release and custom domain prefixes; document final validation results and current capability gaps.
- Order writer/reader proxy operations through module dependencies and preserve old resource addresses with moved blocks.
- Add basic single-AZ, complete cross-AZ with private writer/reader proxies, cross-AZ MultiNode and target read-replica capacity examples.
- Record create-only topology/password/storage boundaries, missing online scale-out contract and unverified real-cloud/Registry gates.
- Validate Terraform 1.5.7 and OpenTofu 1.11.8 with minimum/current Provider versions, negative plans and password redaction checks.
