provider "aws" {
  region = var.aws_region_primary
  default_tags {
    tags = {
      env             = var.stack_env
      app_name        = var.app_name
      service         = var.service
      role            = var.role
      created_by      = var.created_by
      code_repository = var.code_repository
      monitored_by    = var.monitored_by
      cost_center     = var.cost_center
      project         = var.project
      Provider        = var.Provider
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = var.aws_region_primary
  default_tags {
    tags = {
      env             = var.stack_env
      app_name        = var.app_name
      service         = var.service
      role            = var.role
      created_by      = var.created_by
      code_repository = var.code_repository
      monitored_by    = var.monitored_by
      cost_center     = var.cost_center
      project         = var.project
      Provider        = var.Provider
    }
  }
}

provider "aws" {
  alias  = "secondary"
  region = var.aws_region_secondary
  default_tags {
    tags = {
      env             = var.stack_env
      app_name        = var.app_name
      service         = var.service
      role            = var.role
      created_by      = var.created_by
      code_repository = var.code_repository
      monitored_by    = var.monitored_by
      cost_center     = var.cost_center
      project         = var.project
      Provider        = var.Provider
    }
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  default_tags {
    tags = {
      env             = var.stack_env
      app_name        = var.app_name
      service         = var.service
      role            = var.role
      created_by      = var.created_by
      code_repository = var.code_repository
      monitored_by    = var.monitored_by
      cost_center     = var.cost_center
      project         = var.project
      Provider        = var.Provider
    }
  }
}
