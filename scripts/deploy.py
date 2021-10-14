  
from brownie import aavecellar, accounts

def main():
    acct = accounts.load("deployer_account")
    name = "AAVE Cellar Pool Share Token"
    symbol = "ACS"
    lendingPool = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9"
    u_token = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    aavecellar.deploy(name, symbol, lendingPool, u_token, {"from":acct})