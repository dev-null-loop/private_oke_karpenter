variable "karpenter" {
  description = "OCI Karpenter / KPO install and repro settings"
  type = object({
    enabled                  = bool
    namespace                = optional(string, "karpenter")
    chart_version            = string
    release_name             = optional(string, "karpenter")
    cluster_name             = string
    cluster_compartment_name = string
    vcn_compartment_name     = string
    oci_vcn_ip_native        = bool
    ip_families              = optional(list(string), ["IPv4"])
    install_via_bastion      = optional(bool, true)
    bastion_instance_name    = optional(string, "bastion")
    node_pool_name           = string
    nodepool = object({
      name                     = string
      cpu_limit                = number
      memory_limit             = optional(string)
      expire_after             = optional(string, "Never")
      termination_grace_period = optional(string, "120m")
      capacity_types           = optional(list(string), ["on-demand"])
      instance_shapes          = list(string)
      consolidation_policy     = optional(string, "WhenEmpty")
      consolidate_after        = optional(string, "60m")
      budget_nodes             = optional(string, "5%")
    })
    ocinodeclass = object({
      name = string
      shape_configs = optional(list(object({
        ocpus                     = number
        memory_in_gbs             = number
        baseline_ocpu_utilization = optional(string)
      })), [])
      image_config = object({
        image_type        = optional(string, "OKEImage")
        image_id          = optional(string)
        os_filter         = optional(string)
        os_version_filter = optional(string)
      })
      primary_subnet_name          = string
      pod_subnet_names             = optional(list(string), [])
      pod_nsg_names                = optional(list(string), [])
      secondary_vnic_ip_count      = optional(number)
      use_same_node_and_pod_subnet = optional(bool, false)
    })
    repro = optional(object({
      enabled       = optional(bool, false)
      replicas      = optional(number, 50)
      cpu           = optional(string, "2")
      memory        = optional(string, "4Gi")
      image         = optional(string, "busybox:1.36")
      sleep_seconds = optional(number, 3600)
    }), { enabled = false })
  })
  default = {
    enabled                  = false
    chart_version            = "1.1.0"
    cluster_name             = "c"
    cluster_compartment_name = "dev"
    vcn_compartment_name     = "dev"
    oci_vcn_ip_native        = true
    node_pool_name           = "n"
    nodepool = {
      name            = "karpenter-general"
      cpu_limit       = 64
      memory_limit    = "256Gi"
      instance_shapes = ["VM.Standard.E3.Flex"]
    }
    ocinodeclass = {
      name                = "karpenter-general"
      image_config        = {}
      primary_subnet_name = "nodes"
    }
  }
}
