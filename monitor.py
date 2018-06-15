import requests
from bs4 import BeautifulSoup

#monitoring-subsonic@aus.sh
USERNAME = "monitoring"
PASSWORD = "XXXX"

SCHEME = "http"
SUBDOMAIN = "mediastreamsubsonic"
DOMAIN = "aus"
TLD = "sh"

def login(username, password):
    s = requests.session()
    data={'j_username': username, 'j_password': password, 'submit':'Log+in'}
    URL = "%s://%s.%s.%s/j_acegi_security_check" % (SCHEME, SUBDOMAIN, DOMAIN, TLD)
    s.post(URL, data=data)
    return s

def check_version(s):
    URL = "%s://%s.%s.%s/help.view" % (SCHEME, SUBDOMAIN, DOMAIN, TLD)
    html = s.get(URL)
    soup = BeautifulSoup(html.content, 'lxml')
    for version in soup.find_all("td", class_="ruleTableCell"):
        if "build" in version.text:
            if "6.1.1" in version.text:
                print("The version is up to date: 6.1.1")
            else:
                print("The version is not up to date.")
                print("Output: %s" % (version.text))

if __name__ == "__main__":
    session = login(USERNAME, PASSWORD)
    check_version(session)
