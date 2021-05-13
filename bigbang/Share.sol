pragma solidity ^0.6.0;

import "./owner/AdminRole.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract Share is ERC20Burnable, AdminRole {
    constructor() public ERC20("SHARE", "SHARE") {
        _mint(msg.sender, 1 * 10**18);
    }

    function mint(address recipient_, uint256 amount_)
        external
        onlyAdmin
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) external override onlyAdmin {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        external
        override
        onlyAdmin
    {
        super.burnFrom(account, amount);
    }
}

contract SShare is ERC20Burnable, AdminRole {
    constructor() public ERC20("sSHARE", "sSHARE") {
        _mint(msg.sender, 1 * 10**18);
    }

    function mint(address recipient_, uint256 amount_)
        external
        onlyAdmin
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) public override onlyAdmin {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        external
        override
        onlyAdmin
    {
        super.burnFrom(account, amount);
    }
}

contract VShare is ERC20Burnable, AdminRole {
    constructor() external ERC20("vSHARE", "vSHARE") {}

    function mint(address recipient_, uint256 amount_)
        external
        onlyAdmin
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        return balanceAfter >= balanceBefore;
    }

    function burn(uint256 amount) external override onlyAdmin {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        external
        override
        onlyAdmin
    {
        super.burnFrom(account, amount);
    }
}
