<<<<<<< HEAD
=======
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ILegacyMintableERC20, IOptimismMintableERC20} from "./bedrock-contracts/IOptimismMintableERC20.sol";
import {ISemver} from "./bedrock-contracts/ISemver.sol";

>>>>>>> main
/*

                        @@@@@@@@@@                                  
                       @@@@@@@@@@  @@@                              
                      @@@@@@@@@@   @@@@                             
                     @@@@@@@@@@  @@@@@@@                            
                    @@@@@@@@@@  @@@@@@@@@                           
                   @@@@@@@@@@  @@@@@@@@@@                           
                  @@@@@@@@@@  @@@@@@@@@@                            
                 @@@@@@@@@@  @@@@@@@@@@                             
                @@@@@@@@@@  @@@@@@@@@@                @@@@@@@@@@    
               @@@@@@@@@@  @@@@@@@@@@              @@  @@@@@@@@@@   
              @@@@@@@@@@  @@@@@@@@@@              @@@@  @@@@@@@@@@  
             @@@@@@@@@@  @@@@@@@@@@              @@@@@@  @@@@@@@@@@ 
            @@@@@@@@@@  @@@@@@@@@@              @@@@@@@@  @@@@@@@@@@
           @@@@@@@@@@                          @@@@@@@@@@           
          @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  @@@@@@@@  @@@@@@@@@@
         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  @@@@@@  @@@@@@@@@@ 
        @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  @@@@  @@@@@@@@@@  
       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  @@  @@@@@@@@@@   
      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    @@@@@@@@@@    
     @@@@@@@@@@                                      @@@@@@@@@@     
    @@@@@@@@@@    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@      
   @@@@@@@@@@  @@  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@       
  @@@@@@@@@@  @@@@  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@        
 @@@@@@@@@@  @@@@@@  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@         
@@@@@@@@@@  @@@@@@@@  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@          
           @@@@@@@@@@                          @@@@@@@@@@           
@@@@@@@@@@  @@@@@@@@              @@@@@@@@@@  @@@@@@@@@@            
 @@@@@@@@@@  @@@@@@              @@@@@@@@@@  @@@@@@@@@@             
  @@@@@@@@@@  @@@@              @@@@@@@@@@  @@@@@@@@@@              
   @@@@@@@@@@  @@              @@@@@@@@@@  @@@@@@@@@@               
    @@@@@@@@@@                @@@@@@@@@@  @@@@@@@@@@                
                             @@@@@@@@@@  @@@@@@@@@@                 
                            @@@@@@@@@@  @@@@@@@@@@                  
                           @@@@@@@@@@  @@@@@@@@@@                   
                           @@@@@@@@@  @@@@@@@@@@                    
                            @@@@@@@  @@@@@@@@@@                     
                             @@@@   @@@@@@@@@@                      
                              @@@  @@@@@@@@@@                       
                                  @@@@@@@@@@                        


*/

// SPDX-License-Identifier: MIT
<<<<<<< HEAD
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
=======
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
>>>>>>> main
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IOptimismMintableERC20, ILegacyMintableERC20} from "./bedrock-contracts/IOptimismMintableERC20.sol";

/// @title Wrapped Handshake ERC20
/// @notice Wrapped Handshake ERC20 is a token contract that implements the IOptimismMintableERC20 interface
///         and serves as the L2 representation of the WHNS token.
<<<<<<< HEAD
contract WrappedHandshake is ERC20, IERC165, IOptimismMintableERC20, ILegacyMintableERC20 {
    address public REMOTE_TOKEN;
    address public BRIDGE;
    uint8 private DECIMALS;

    error OnlyBridge();
=======
contract WrappedHandshake is Initializable, ERC20Upgradeable, IOptimismMintableERC20, ILegacyMintableERC20 {
    address public REMOTE_TOKEN;
    address public BRIDGE;
    address public deployer;
    uint8 private DECIMALS;

    /// @notice Emitted whenever tokens are minted for an account.
    event Mint(address indexed account, uint256 amount);

    /// @notice Emitted whenever tokens are burned from an account.
    event Burn(address indexed account, uint256 amount);

    error OnlyBridge();
    error OnlyDeployer();
>>>>>>> main

    /// @notice Ensures only the bridge contract can call specific functions.
    modifier onlyBridge() {
        if (msg.sender != BRIDGE) {
            revert OnlyBridge();
        }
        _;
    }

<<<<<<< HEAD
    /// @dev Constructor to disable initializers in the implementation contract.
    ///      This prevents the implementation from being initialized directly.
    constructor(address _bridge, address _remoteToken) ERC20("Wrapped Handshake", "WHNS") {
        REMOTE_TOKEN = _remoteToken;
        BRIDGE = _bridge;
        DECIMALS = 18; // Token has 18 decimal places
=======
    /// @notice Ensures only the deployer can call specific functions.
    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert OnlyDeployer();
        }
        _;
    }

    /// @dev Constructor to disable initializers in the implementation contract.
    ///      This prevents the implementation from being initialized directly.
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializer function instead of a constructor for upgradeable contracts.
    /// @param _bridge Address of the L2 standard bridge.
    /// @param _remoteToken Address of the corresponding L1 token.
    function initializeWrappedHandshake(
        address _bridge,
        address _remoteToken
    ) public initializer {
        __ERC20_init("Wrapped Handshake", "WHNS");
        REMOTE_TOKEN = _remoteToken;
        BRIDGE = _bridge;
        DECIMALS = 6; // Token has 6 decimal places
        deployer = msg.sender; // Save the deployer's address
>>>>>>> main
    }

    /// @notice Allows the StandardBridge on this network to mint tokens.
    /// @param _to     Address to mint tokens to.
    /// @param _amount Amount of tokens to mint.
<<<<<<< HEAD
    function mint(address _to, uint256 _amount)
        external
        override(ILegacyMintableERC20, IOptimismMintableERC20)
        onlyBridge
    {
        _mint(_to, _amount);
=======
    function mint(address _to, uint256 _amount) external  override(ILegacyMintableERC20, IOptimismMintableERC20) onlyBridge {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
>>>>>>> main
    }

    /// @notice Allows the StandardBridge on this network to burn tokens.
    /// @param _from   Address to burn tokens from.
    /// @param _amount Amount of tokens to burn.
<<<<<<< HEAD
    function burn(address _from, uint256 _amount)
        external
        override(ILegacyMintableERC20, IOptimismMintableERC20)
        onlyBridge
    {
        _burn(_from, _amount);
=======
    function burn(address _from, uint256 _amount) override(ILegacyMintableERC20, IOptimismMintableERC20) external onlyBridge {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
>>>>>>> main
    }

    /// @dev ERC165 interface check function.
    /// @param _interfaceId Interface ID to check.
    /// @return Whether or not the interface is supported by this contract.
    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        bytes4 iface2 = type(ILegacyMintableERC20).interfaceId;
        bytes4 iface3 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface2 || _interfaceId == iface3;
    }

    /// @dev Returns the number of decimals used to get its user representation.
    /// @return The number of decimals the token uses.
    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }

    /// @custom:legacy
    /// @notice Legacy getter for the remote token. Use REMOTE_TOKEN going forward.
    function l1Token() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for the bridge. Use BRIDGE going forward.
    function l2Bridge() public view returns (address) {
        return BRIDGE;
    }

<<<<<<< HEAD
    /// @custom:legacy
=======
        /// @custom:legacy
>>>>>>> main
    /// @notice Legacy getter for REMOTE_TOKEN.
    function remoteToken() public view returns (address) {
        return REMOTE_TOKEN;
    }

    /// @custom:legacy
    /// @notice Legacy getter for BRIDGE.
    function bridge() public view returns (address) {
        return BRIDGE;
    }
}
<<<<<<< HEAD
=======

>>>>>>> main
