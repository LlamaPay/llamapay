import pytest
from brownie_tokens import ERC20


@pytest.fixture(scope="module")
def alice(accounts):
    return accounts[0]

@pytest.fixture(scope="module")
def factory(alice, LlamaPayFactory):
    return LlamaPayFactory.deploy({"from": alice})

@pytest.fixture(scope="module")
def token():
    return ERC20()
