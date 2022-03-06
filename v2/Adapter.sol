//SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract Adapter {
    function deposit(address vault, uint256 amount) public virtual;
    function withdraw(address vault, uint256 amount) public virtual;
    function pricePerShare(address vault) public view virtual returns (uint256);
    function refreshSetup(address token, address vault) public virtual {
        IERC20(token).approve(vault, type(uint).max);
    }
}

interface YearnVault {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 maxShares) external;
    function pricePerShare() external view returns (uint);
}

contract YearnAdapter is Adapter {
    function deposit(address vault, uint256 amount) public override { 
        YearnVault(vault).deposit(amount);
    }

    function withdraw(address vault, uint256 amount) public override { 
        YearnVault(vault).withdraw(amount);
    }

    function pricePerShare(address vault) public view override returns (uint256){
        return YearnVault(vault).pricePerShare();
    }
}

interface BeefyVault {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 maxShares) external;
    function getPricePerFullShare() external view returns (uint);
}

contract BeefyAdapter is Adapter {
    function deposit(address vault, uint256 amount) public override { 
        BeefyVault(vault).deposit(amount);
    }

    function withdraw(address vault, uint256 amount) public override { 
        BeefyVault(vault).withdraw(amount);
    }
    
    function pricePerShare(address vault) public view override returns (uint256){
        return BeefyVault(vault).getPricePerFullShare();
    }
}

interface CompoundToken {
    function mint(uint256 mintAmount) external;
    function redeem(uint256 redeemTokens) external;
    function exchangeRateStored() external view returns (uint);
}

contract CompoundAdapter is Adapter {
    function deposit(address vault, uint256 amount) public override { 
        CompoundToken(vault).mint(amount);
    }

    function withdraw(address vault, uint256 amount) public override { 
        CompoundToken(vault).redeem(amount);
    }
    
    function pricePerShare(address vault) public view override returns (uint256){
        return CompoundToken(vault).exchangeRateStored();
    }
}