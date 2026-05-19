data "oci_core_services" "this" {}

locals {
  network_entity_ids = merge(
    { for k, v in module.ig : "ig_${k}" => v.id },
    { for k, v in module.ng : "ng_${k}" => v.id },
    { for k, v in module.sg : "sg_${k}" => v.id },
  )

  service_destinations = {
    services = one([
      for s in data.oci_core_services.this.services : s.cidr_block
      if can(regex("^all-.*-services-in-oracle-services-network$", s.cidr_block))
    ])

    objectstorage = one([
      for s in data.oci_core_services.this.services : s.cidr_block
      if can(regex("^oci-.*-objectstorage$", s.cidr_block))
    ])
  }

  security_lists_resolved = {
    for sl_name, sl in var.security_lists : sl_name => merge(sl, {
      egress_rules = [
        for rule in sl.egress_rules : merge(rule, {
          destination = lookup(local.service_destinations, rule.destination, rule.destination)
        })
      ]
    })
  }

  route_tables_resolved = {
    for rt_name, rt in var.route_tables : rt_name => merge(rt, {
      route_rules = [
        for rr in rt.route_rules : {
          description       = try(rr.description, null)
          destination       = lookup(local.service_destinations, rr.destination, rr.destination)
          destination_type  = try(rr.destination_type, "CIDR_BLOCK")
          network_entity_id = local.network_entity_ids[rr.network_entity_name]
        }
      ]
    })
  }

  missing_network_entities = flatten([
    for rt_name, rt in var.route_tables : [
      for rr in rt.route_rules : "${rt_name}:${rr.network_entity_name}"
      if !contains(keys(local.network_entity_ids), rr.network_entity_name)
    ]
  ])

  #node_pool_tags=join(",", [for k,v in each.value.node_pool_tags} : $"${key}"=$"${value}"])}
}

check "route_rule_targets_exist" {
  assert {
    condition     = length(local.missing_network_entities) == 0
    error_message = "Unknown route rule network_entity_name values: ${join(", ", local.missing_network_entities)}"
  }
}
