pragma solidity 0.5.12;

interface IERC20 {
    function transfer(address to, uint value) external returns (bool);

    function approve(address spender, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);

    function totalSupply() external view returns (uint);

    function balanceOf(address who) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    event Transfer(address indexed from, address indexed to, uint value);

    event Approval(address indexed owner, address indexed spender, uint value);
}
