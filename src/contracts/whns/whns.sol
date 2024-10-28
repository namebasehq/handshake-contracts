// SPDX-License-Identifier: MIT
<<<<<<< HEAD
pragma solidity 0.8.28;
=======
pragma solidity 0.8.17;
>>>>>>> main

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

<<<<<<< HEAD
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

=======
>>>>>>> main
contract WrappedHandshake is ERC20, Ownable {
    uint8 private _decimals;

    constructor(uint8 decimals_) ERC20("Wrapped Handshake", "WHNS") {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
