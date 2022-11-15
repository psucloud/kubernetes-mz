resource "kubernetes_service" "materialize" {
  metadata {
    name = "materialize-headless"
    labels = {
      app = "materialize-svc"
    }
    namespace = "materialize"
  }

  spec {
    selector = {
      app = kubernetes_stateful_set.materialize.metadata.0.labels.app
    }

    type                        = "ClusterIP"
    cluster_ip                  = "None"
    publish_not_ready_addresses = true

    port {
      name        = "materialize"
      port        = 6875
      target_port = "materialize"
    }
  }
}

resource "kubernetes_stateful_set" "materialize" {
  metadata {
    name = "materialize"
    labels = {
      app = "materialize"
    }
    namespace = "materialize"
  }

  spec {
    replicas = 1

    update_strategy {
      type = "RollingUpdate"
    }

    service_name          = "materialize-headless"
    pod_management_policy = "Parallel"

    selector {
      match_labels = {
        app = "materialize"
      }
    }

    template {
      metadata {
        labels = {
          app = "materialize"
        }
      }

      spec {
        container {
          image = local.materializeImagee
          name  = "materialize"
          args  = ["--workers", "2", "--data-directory=/app/mzdata", "--log-filter=DEBUG"]

          port {
            container_port = 6875
            name           = "materialize"
          }

          liveness_probe {
            http_get {
              path   = "/status"
              port   = 6875
              scheme = "HTTP"
            }

            initial_delay_seconds = 3
            period_seconds        = 30
          }

          volume_mount {
            mount_path = "/app/mzdata"
            name       = "materialize-pvc"
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "1"
            }

            limits = {
              cpu = "2"
            }
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "materialize-pvc"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = local.blockStorageClassName
        resources {
          requests = {
            storage = "16Gi"
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.rook_cluster
  ]
}