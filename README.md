# [WIP]MySQL image builder, Docker In Docker

## env
### Origin DB
| key | val |
| - | - |
| ORIGIN_USER | root |
| ORIGIN_PASS | password |
| ORIGIN_DB_NAME | development_database |

### New MySQL Image
| key | val |
| - | - |
| MYSQL_ROOT_PASSWORD | password |

### AWS CLI
| key | val |
| - | - |
| AWS_ACCESS_KEY_ID | xxx |
| AWS_SECRET_ACCESS_KEY | xxx |
| AWS_DEFAULT_REGION | ap-northeast-1 |
| AWS_DEFAULT_OUTPUT | json |

### AWS RDS Cluster Snapshot
| key | val |
| - | - |
| DB_CLUSTER_IDENTIFIER | xxx |

### AWS RDS Cluster WorkingInstance
| key | val |
| - | - |
| TMP_CLUSTER | mysql-builder |
| TMP_CLUSTER_CLASS | db.t2.small |

### AWS ECR
| key | val |
| - | - |
| REPOSITORY_URI | xxx.ecr.ap-northeast-1.amazonaws.com/builded_mysql |
| REPOSITORY_TAG | latest |
