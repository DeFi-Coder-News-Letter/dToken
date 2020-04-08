pragma solidity 0.5.12;

interface IHandler {
    function deposit(address _token) external returns (bool);
    function withdraw(address _token, uint _amount) external returns (uint);
    function redeem(address _token, uint _amount) external returns (uint, uint);
    function getBalance(address _token) external view returns (uint);
    function getLiquidity(address _token) external view returns (uint);
    function getRealBalance(address _token) external view returns (uint);
    function getInterestRate(address _token) external view returns (uint);
    function getRealAmount(uint _pie) external view returns (uint);
}
