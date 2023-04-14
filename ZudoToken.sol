// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC20.sol";

contract ZudoToken is ERC20 {
    using SafeMath for uint256;
    uint256 public constant MAX_TOTAL_SUPPLY = 21_000_000e18;

    constructor(uint256 _initialSupply) ERC20("ZUDO Token", "ZUDO") {
        _mint(msg.sender, _initialSupply);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        require(
            _amount + totalSupply() <= MAX_TOTAL_SUPPLY,
            "ZudoToken: Max total supply exceeded"
        );
        _mint(_to, _amount);
    }

    // Safe zudo transfer function
    function safeZudoTransfer(address _to, uint256 _amount) public onlyOwner {
        uint256 zudoBal = balanceOf(address(this));
        if (_amount > zudoBal) {
            _transfer(address(this), _to, zudoBal);
        } else {
            _transfer(address(this), _to, _amount);
        }
    }
}