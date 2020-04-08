#!/usr/bin/python3

from brownie.test import given, strategy

import pytest
import brownie


MAX_VALUE = 115792089237316195423570985008687907853269984665640564039457584007913129639935


def test_preparation(USDx, dispatcher, handler, accounts):
    assert USDx.balanceOf(accounts[0]) == 100000e18


# @given(amount=strategy('uint', max_value=1000))
def test_mint(dToken, USDx, accounts):
    USDx.approve(dToken, MAX_VALUE, {'from': accounts[2]})
    assert USDx.allowance(accounts[2], dToken) == MAX_VALUE
    assert dToken.balanceOf(accounts[2]) == 0
    dToken.mint(accounts[2], 100e18, {'from': accounts[2]})
    assert dToken.balanceOf(accounts[2]) == 100e18
    # dToken.mint(accounts[2], amount, {'from': accounts[2]})
    # assert dToken.balanceOf(accounts[2]) == amount


def test_burn(dToken, USDx, accounts):
    USDx.approve(dToken, MAX_VALUE, {'from': accounts[2]})
    dToken.mint(accounts[2], 100e18, {'from': accounts[2]})
    assert USDx.allowance(accounts[2], dToken) == MAX_VALUE
    assert dToken.balanceOf(accounts[2]) == 100e18
    dToken.burn(accounts[2], 100e18, {'from': accounts[2]})
    assert dToken.balanceOf(accounts[2]) == 0


def test_getHandler(dToken, dispatcher):
    actual_handlers, _ = dispatcher.getHandler()
    assert dToken.getHandler() == actual_handlers


def test_getExchangeRate(dToken, dispatcher):
    assert dToken.getExchangeRate() == 1e18


@pytest.mark.parametrize('idx', [0, 1, 2])
def test_dToken_mint_reverts(dToken, accounts, idx):
    '''mint should revert'''
    with brownie.reverts("ds-token-insufficient-approval"):
        dToken.mint(accounts[idx], 100e18, {'from': accounts[idx]})
