#we're creating a public and private network for each az.
#things in the public networks are talking to each other with public ip addresses, and have public internet routes
#the private network only has internet access through a nat

# 172.17.0.0/16 reserved for docker
# 172.24.0.0/16 used as global transit network, also called "wan", authorized through wireguard
    # 172.24.1.1    the peering gateway
    # 172.24.1.0/16 devs
    # 172.24.2.0/16 hetzner machines
# 172.30.0.0/16 this vpc

resource "aws_vpc" "main" {
    cidr_block = "172.30.0.0/16"
    tags {
        Name  = "${terraform.env}"
        Stage = "${terraform.env}"
    }
}

resource "aws_subnet" "main-private" {
    count             = "${length(data.aws_availability_zones.available.names)}"
    vpc_id            = "${aws_vpc.main.id}"
    availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
    cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)}"

    tags {
        Tier  = "private"
        Stage = "${terraform.env}"
        Name  = "${terraform.env}-private-${data.aws_availability_zones.available.names[count.index]}"
    }
}

resource "aws_subnet" "main-public" {
    map_public_ip_on_launch = true
    count             = "${length(data.aws_availability_zones.available.names)}"
    vpc_id            = "${aws_vpc.main.id}"
    availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
    cidr_block        = "${cidrsubnet(cidrsubnet(aws_vpc.main.cidr_block, 4,
                           length(data.aws_availability_zones.available.names)), 2, count.index)  }"
    tags {
        Tier  = "public"
        Stage = "${terraform.env}"
        Name  = "${terraform.env}-public-${data.aws_availability_zones.available.names[count.index]}"
    }
}

resource "aws_eip" "main-nat" {
    vpc = true
}

resource "aws_internet_gateway" "main-gw" {
    vpc_id = "${aws_vpc.main.id}"

    tags {
        Name  = "${terraform.env}-gw"
        Stage = "${terraform.env}"
    }
}

resource "aws_nat_gateway" "main-gw" {
    allocation_id   = "${aws_eip.main-nat.id}"
    depends_on      = ["aws_internet_gateway.main-gw"]
    subnet_id       = "${aws_subnet.main-public.0.id}"

}

resource "aws_route_table" "main-public" {
    vpc_id = "${aws_vpc.main.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.main-gw.id}"
    }

    route {
        cidr_block = "172.24.0.0/16"
        instance_id = "${aws_instance.border.id}"
    }

    tags {
        Name  = "${terraform.env}-public"
        Stage = "${terraform.env}"
    }
}

resource "aws_route_table_association" "main-public" {
    count          = "${length(data.aws_availability_zones.available.names)}"
    subnet_id      = "${aws_subnet.main-public.*.id[count.index]}"
    route_table_id = "${aws_route_table.main-public.id}"
}

resource "aws_route_table" "main-private" {
    vpc_id = "${aws_vpc.main.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_nat_gateway.main-gw.id}"
    }

    route {
        cidr_block = "172.24.0.0/16"
        instance_id = "${aws_instance.border.id}"
    }

    tags {
        Name  = "${terraform.env}-private"
        Stage = "${terraform.env}"
    }
}

resource "aws_route_table_association" "main-private" {
    count          = "${length(data.aws_availability_zones.available.names)}"
    subnet_id      = "${aws_subnet.main-private.*.id[count.index]}"
    route_table_id = "${aws_route_table.main-private.id}"
}


output "subnets-public" {
    value = ["${aws_subnet.main-public.*.id}"]
}

output "subnets-private" {
    value = ["${aws_subnet.main-private.*.id}"]
}
