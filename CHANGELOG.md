# Changelog

## Initial implementation

- Add an RDS MySQL MultiNode and DoubleNode module with explicit network ownership, sensitive administrator input, replica topology, running-instance backup policy and parameter templates.
- Remove unsupported controls for backup public download, retention after release and custom domain prefixes.
- Order writer/reader proxy operations through module dependencies and preserve old resource addresses with moved blocks.
- Add basic single-AZ, complete cross-AZ with private writer/reader proxies, cross-AZ MultiNode and target read-replica capacity examples.
- Document create-only topology, password and storage settings, and the read-replica capacity configuration.
- Add bilingual module and example documentation with Terraform and OpenTofu version requirements.
