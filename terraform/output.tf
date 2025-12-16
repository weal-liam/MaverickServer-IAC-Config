output "maverick_server_public_ip" {
  value = aws_instance.maverick_server.public_ip
}

/*output "kubeconfig" {
  value = aws_eks_cluster.weal_eks_cluster.endpoint
}

output "cluster_CA" {
    value = aws_eks_cluster.weal_eks_cluster.certificate_authority[0].data
}

output "cluster_token" {
    value = aws_eks_cluster.weal_eks_cluster.identity[0].oidc[0].issuer
}

output "alb_dns_name" {
  value = aws_lb.weal_lb.dns_name
}
*/