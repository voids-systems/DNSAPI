import configparser

config = configparser.ConfigParser()
config.read('config.ini')

API_KEY = config['Settings']['API_KEY']
DOMAIN = config['Settings']['DOMAIN']
