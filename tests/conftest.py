from brownie import Wei

import pytest

MAX_VALUE = 115792089237316195423570985008687907853269984665640564039457584007913129639935


@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    pass


# @pytest.fixture(scope="module")
# def token(Token, accounts):
#     return accounts[0].deploy(Token, "Test Token", "TST", 18, 1e21)

@pytest.fixture(scope="module")
def USDx(usdxFaucet, accounts):
    token = accounts[0].deploy(
        usdxFaucet, '0x5553447800000000000000000000000000000000000000000000000000000000')
    token.allocateTo(accounts[0], Wei('100000 ether'), {
                     'from': accounts[0]})  # owner
    token.allocateTo(accounts[1], Wei('10000 ether'),
                     {'from': accounts[1]})  # manager
    token.allocateTo(accounts[2], Wei('10000 ether'),
                     {'from': accounts[2]})  # user1
    token.allocateTo(accounts[3], Wei('10000 ether'),
                     {'from': accounts[3]})  # user2
    return token


@pytest.fixture(scope="module")
def weth(wethFaucet, accounts):
    token = accounts[0].deploy(wethFaucet)
    token.allocateTo(accounts[0], Wei('100000 ether'), {'from': accounts[0]})
    return token


@pytest.fixture(scope="module")
def dToken(DToken, USDx, accounts):
    return accounts[0].deploy(DToken, 'dUSDx', 'dUSDx', 18, USDx, USDx, 0)


@pytest.fixture(scope="module")
def handler(Handler, dToken, USDx, accounts):
    fake_market = accounts[9]
    handler_contract = accounts[0].deploy(Handler, fake_market, dToken)
    handler_contract.approve(USDx)
    return handler_contract

@pytest.fixture(scope="module")
def handler1(Handler, dToken, USDx, accounts):
    fake_market = accounts[8]
    handler_contract = accounts[0].deploy(Handler, fake_market, dToken)
    handler_contract.approve(USDx)
    return handler_contract


@pytest.fixture(scope="module")
def dispatcher(Dispatcher, handler, dToken, accounts):
    dispatcher_contract = accounts[0].deploy(Dispatcher, [handler], [1000])
    print('before account1 is manager: ', dToken.isManager(accounts[1]))
    dToken.setManager(accounts[1])
    print('after account1 is manager: ', dToken.isManager(accounts[1]))
    print('before dispatcher address is: ', dToken.dispatcher())
    dToken.updateDispatcher(dispatcher_contract, {"from": accounts[1]})
    print('after dispatcher address is: ', dToken.dispatcher())
    return dispatcher_contract
