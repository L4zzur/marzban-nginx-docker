# marzban-nginx-docker

## Prerequisites

Before running the installation script, please complete the following steps:

1.  **Server:** Obtain a VPS or VDS server with a public IP address. A location outside of restrictive regions is recommended. Note down your server's public IP address.
2.  **Domain Name:** Purchase a domain name.
    *   Consider registrars like NameSilo or Porkbun. Affordable TLDs like `.xyz`, `.top`, or `.link` are suitable.
3.  **Cloudflare Account:** Register for a free account at [Cloudflare](https://www.cloudflare.com/).
4.  **Add Domain to Cloudflare:**
    *   In your Cloudflare dashboard, select "Add a domain" and enter the domain name you purchased.
    *   Choose the "Free" plan when prompted.
5.  **Update Nameservers:**
    *   Log in to your domain registrar's control panel (where you purchased the domain).
    *   **Disable DNSSEC** for your domain if it is currently enabled. Instructions vary by registrar; consult their documentation or see Cloudflare's general guidance [here](https://developers.cloudflare.com/dns/dnssec#disable-dnssec).
    *   Find the nameserver management section for your domain.
    *   **Replace** the existing nameservers with the two nameservers provided by Cloudflare. Ensure only Cloudflare's nameservers remain. Specific instructions for various registrars can be found [here](https://developers.cloudflare.com/dns/nameservers/update-nameservers/#your-domain-uses-a-different-registrar).
    *   In Cloudflare, proceed to the step where it checks for the nameserver change. Wait for Cloudflare to confirm that your domain is active (this can take some time for DNS propagation).
6.  **Configure Cloudflare DNS Records:**
    *   Once your domain is active in Cloudflare, navigate to the "DNS" -> "Records" section for your domain.
    *   Delete any pre-existing DNS records (especially A, AAAA, or CNAME records) that might point to old hosting or your server IP for the root domain or the subdomains you plan to use.
    *   Add three **A** records, all pointing to your server's public IP address:
        *   **Type:** `A`, **Name:** `@`, **Content:** `<Your Server IP>`, **Proxy status:** `DNS only` (grey cloud)
        *   **Type:** `A`, **Name:** `sub` (or your chosen name, e.g., `cdn`), **Content:** `<Your Server IP>`, **Proxy status:** `DNS only` (grey cloud)
        *   **Type:** `A`, **Name:** `panel` (or your chosen name), **Content:** `<Your Server IP>`, **Proxy status:** `DNS only` (grey cloud)
    *   **Crucial:** Ensure the **Proxy status** for all three records is set to **DNS only** (grey cloud icon). *Do not* use the "Proxied" (orange cloud) setting, as this will interfere with SSL certificate validation by acme.sh.
    *   Leave the TTL setting as "Auto".
    *   Note the exact names you used for the subdomains (`sub`, `panel`, or your custom choices), as you will need them during the installation script.
7.  **Verify DNS Propagation:**
    *   Wait a few minutes for the DNS records to start propagating.
    *   Go to a DNS checking tool like [whatsmydns.net](https://www.whatsmydns.net/).
    *   Enter your main domain name (e.g., `yourdomain.com`) and select "A" record type. Check if the IP address displayed across different locations matches your server's IP.
    *   Repeat the check for your subdomains (e.g., `sub.yourdomain.com` and `panel.yourdomain.com`), also checking for "A" records.
    *   Proceed to the installation only when the DNS records correctly show your server's IP address globally or in most locations. Propagation can take time, sometimes up to 48 hours, but often much faster (`[2]`).

## Installation

Run the following command on your server:
```bash
bash -c "$(curl -sL https://github.com/L4zzur/marzban-nginx-docker/raw/main/install.sh)"
```