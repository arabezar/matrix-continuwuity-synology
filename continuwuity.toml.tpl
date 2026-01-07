[global]
server_name = "${DOMAIN_BASE}"
address = "0.0.0.0"
port = 6167

database_path = "/var/lib/continuwuity"
new_user_displayname_suffix = ""
allow_announcements_check = true
max_request_size = 52428800 # 50MB
allow_registration = false
yes_i_am_very_very_sure_i_want_an_open_registration_server_prone_to_abuse = true
registration_token = "${SECRET_TOKEN}"
allow_encryption = true
allow_federation = true
trusted_servers = ["matrix.org"]

allow_local_presence = true
allow_incoming_presence = true
allow_outgoing_presence = true
allow_local_read_receipts = true
allow_incoming_read_receipts = true
allow_outgoing_read_receipts = true
allow_local_typing = true
allow_outgoing_typing = true
allow_incoming_typing = true

[global.tls]

[global.well_known]

[global.blurhashing]

[global.ldap]
