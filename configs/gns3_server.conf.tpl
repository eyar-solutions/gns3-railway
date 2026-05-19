[Server]
host = 0.0.0.0
port = 3080
images_path = /gns3/images
projects_path = /gns3/projects
appliances_path = /gns3/appliances
configs_path = /gns3/configs
auth = ${GNS3_AUTH}
user = ${GNS3_USER}
password = ${GNS3_PASSWORD}
report_errors = False

[Dynamips]
allocate_aux_console_ports = False
mmap_support = True
sparse_memory_support = True

[Docker]
