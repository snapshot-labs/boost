// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, Ownable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // mint function
    function mintForSelf(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
