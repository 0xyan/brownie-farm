from scripts.helpful_scripts import get_account, get_contract
from brownie import DappToken, TokenFarm, config, network

KEPT_BALANCE = 100000


def deploy_token_farm():
    account = get_account()
    dapp_token = DappToken.deploy({"from": account})
    token_farm = TokenFarm.deploy(
        dapp_token.address,
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    # sending balance to the farming contract
    tx = dapp_token.transfer(
        token_farm.address, dapp_token.totalSupply() - KEPT_BALANCE, {"from": account}
    )
    tx.wait(1)
    print("total supply sent")

    # can farm with: dapp_token, weth_token, fau_token
    weth_token = get_contract("weth_token")
    fau_token = get_contract("fau_token")

    # dictionary of token: price feed contract
    dict_of_allowed_tokens = {
        dapp_token: get_contract("dai_usd_price_feed"),
        fau_token: get_contract("dai_usd_price_feed"),
        weth_token: get_contract("eth_usd_price_feed"),
    }
    print(dict_of_allowed_tokens)

    add_allowed_tokens(token_farm, dict_of_allowed_tokens, account)
    return token_farm, dapp_token


# looping through dictionary and calling contract functions to add tokens to farm and add oracle
def add_allowed_tokens(token_farm, dict_of_allowed_tokens, account):
    for token in dict_of_allowed_tokens:
        add_tx = token_farm.addAllowedTokens(token.address, {"from": account})
        add_tx.wait(1)
        set_tx = token_farm.addPriceFeedMappings(
            token.address, dict_of_allowed_tokens[token], {"from": account}
        )
        set_tx.wait(1)
    return token_farm


def main():
    deploy_token_farm()
