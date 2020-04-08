from brownie.test import given, strategy

import pytest
import brownie

MAX_VALUE = 115792089237316195423570985008687907853269984665640564039457584007913129639935


def test_preparation(USDx, dToken, dispatcher, handler, accounts):
    assert USDx.balanceOf(accounts[0]) == 100000e18


def test_add_handler(dispatcher, handler1, accounts):
    print('before account1 is manager: ', dispatcher.isManager(accounts[1]))
    dispatcher.setManager(accounts[1])
    print('after account1 is manager: ', dispatcher.isManager(accounts[1]))
    print('before add handlers, there are: ', dispatcher.getHandler())
    dispatcher.addHandler([handler1], {'from': accounts[1]})
    print('after add handlers, there are: ', dispatcher.getHandler())
    handlers, _ = dispatcher.getHandler()
    print('handler are: ', handlers, type(handlers))
    dispatcher.updatePropotion(handlers, [700, 300], {'from': accounts[1]})
    print('after update handlers, there are: ', dispatcher.getHandler())


@pytest.mark.parametrize('amount', [100, 99.999999, 0.99999])
def test_add_handler_then_burn(dispatcher, handler1, dToken, USDx, accounts, amount):
    dispatcher.setManager(accounts[1])
    print('before add handlers, there are: ', dispatcher.getHandler())
    dispatcher.addHandler([handler1], {'from': accounts[1]})
    print('after add handlers, there are: ', dispatcher.getHandler())
    handlers, _ = dispatcher.getHandler()
    dispatcher.updatePropotion(handlers, [700, 300], {'from': accounts[1]})
    print('after update propotion, handlers are: ', dispatcher.getHandler())

    USDx.approve(dToken, MAX_VALUE, {'from': accounts[2]})
    USDx.approve(dToken, MAX_VALUE, {'from': accounts[3]})
    print('dtoken handler are: ', dToken.getHandler())
    dToken.mint(accounts[2], amount, {'from': accounts[2]})
    dToken.mint(accounts[3], amount, {'from': accounts[3]})
    assert USDx.allowance(accounts[2], dToken) == MAX_VALUE
    assert USDx.allowance(accounts[3], dToken) == MAX_VALUE
    assert dToken.balanceOf(accounts[2]) == amount
    assert dToken.balanceOf(accounts[3]) == amount
    dToken.burn(accounts[3], amount, {'from': accounts[3]})
    dToken.burn(accounts[2], amount, {'from': accounts[2]})
    assert dToken.balanceOf(accounts[3]) == 0
    assert dToken.balanceOf(accounts[2]) == 0
