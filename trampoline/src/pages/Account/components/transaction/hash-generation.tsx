import React, { useState } from 'react';
import { ethers } from 'ethers';
import type { BaseContract, BigNumber, BigNumberish, BytesLike, CallOverrides, ContractTransaction, Overrides, PayableOverrides, PopulatedTransaction, Signer, utils } from "ethers";
import {
  HashGenerationConfirmation,
  HashGenerationProps,
} from '../types';
import {
  Button,
  TextField,
  Dialog,
  DialogContent,
  DialogActions,
} from '@mui/material';
import { UserOperationStruct } from '@account-abstraction/contracts';

const generateHash = (userOp: UserOperationStruct) => {
    console.log(userOp)
    userOp.nonce = '0x09';
    userOp.initCode = "0x";
    userOp.paymasterAndData = "0x";
    const hash= ethers.utils.solidityKeccak256(
    ['address', 'uint256', 'bytes', 'bytes'],
    [
        userOp.sender,
        userOp.nonce,
        userOp.initCode,
        userOp.paymasterAndData,
    ]);
    console.log(hash);
    return hash;
}
const HashGenerationConfirmationComponent: HashGenerationConfirmation = ({
  userOp,
  context,
  onComplete,
}: HashGenerationProps) => {
  const [open, setOpen] = useState(true);

  const handleComplete = () => {
    onComplete(context);
    setOpen(false);
  };
  const hashvalue = generateHash(userOp);

  return (
    <Dialog open={open} onClose={() => setOpen(false)}>
      <DialogContent>
        {hashvalue}
      </DialogContent>
      <DialogActions>
        <Button onClick={() => setOpen(false)}>Cancel</Button>
        <Button onClick={handleComplete}>
          Next
        </Button>
      </DialogActions>
    </Dialog>

  );
};

export default HashGenerationConfirmationComponent;
