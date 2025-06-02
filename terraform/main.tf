resource "aws_vpc" "weal_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_eks_cluster" "weal_eks_cluster" {
  name     = "weal-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.weal_public_subnet.id, aws_subnet.weal_public_subnet_b.id]
    security_group_ids = [aws_security_group.weal_sg.id]
  }

  depends_on = [aws_internet_gateway.weal_igw, aws_route_table_association.weal_public_route_table_association]

  tags = {
    Name = "weal-eks-cluster"
  }
  
}

resource "aws_subnet" "weal_public_subnet" {
  vpc_id                  = aws_vpc.weal_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_subnet" "weal_public_subnet_b" {
  vpc_id                  = aws_vpc.weal_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-north-1b"

  tags = {
    Name = "dev-public-b"
  }
}

resource "aws_internet_gateway" "weal_igw" {
  vpc_id = aws_vpc.weal_vpc.id

  tags = {
    Name = "dev-igw"
  }
}
resource "aws_route_table" "weal_public_route_table" {
  vpc_id = aws_vpc.weal_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.weal_igw.id
  }
}
resource "aws_route_table_association" "weal_public_route_table_association" {
  subnet_id      = aws_subnet.weal_public_subnet.id
  route_table_id = aws_route_table.weal_public_route_table.id
}

resource "aws_route_table_association" "weal_public_route_table_association_b" {
  subnet_id      = aws_subnet.weal_public_subnet_b.id
  route_table_id = aws_route_table.weal_public_route_table.id
}

resource "aws_security_group" "weal_sg" {
  vpc_id = aws_vpc.weal_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH access"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  tags = {
    Name = "dev-sg"
  }
}


resource "aws_key_pair" "maverick_key" {
  key_name   = "maverick_key"
  public_key = file("~/.ssh/maverick_key.pub")
}


resource "aws_instance" "maverick_server" {
  ami           = data.aws_ami.maverick_server_ami.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.weal_public_subnet.id
  key_name      = aws_key_pair.maverick_key.key_name
  vpc_security_group_ids = [aws_security_group.weal_sg.id]

  tags = {
    Name = "MaverickServer"
  }
  root_block_device {
    volume_size = 20
	encrypted = true
  }
}



resource "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRole"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


resource "aws_iam_role" "eks_node_role" {
  name = "eksNodeRole"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "weal_node_group" {
  cluster_name    = aws_eks_cluster.weal_eks_cluster.name
  node_group_name = "weal-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.weal_public_subnet.id, aws_subnet.weal_public_subnet_b.id]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.micro"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly
  ]
}