import React, { useState } from 'react';
import {
  UpdateSignatureConfirmation,
  UpdateSignatureProps,
} from '../types';
import {
  Button,
  TextField,
  Dialog,
  DialogContent,
  DialogActions,
} from '@mui/material';

const UpdateSignatureConfirmationComponent: UpdateSignatureConfirmation = ({
  userOp,
  context,
  onComplete,
  updateSignature,
}: UpdateSignatureProps) => {
  const [open, setOpen] = useState(true);
  const [sig, setsignature] = useState('');

  const handleComplete = () => {
    onComplete(context);
    setOpen(false);
    updateSignature(sig);
  };

  const handleSigChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setsignature(e.target.value);
  }

  return (
    <Dialog open={open} onClose={() => setOpen(false)}>
      <DialogContent>
        <TextField
          label="Enter Signature"
          variant="outlined"
          fullWidth
          value={sig}
          onChange={handleSigChange}
        />
      </DialogContent>
      <DialogActions>
        <Button onClick={() => setOpen(false)}>Cancel</Button>
        <Button onClick={handleComplete} disabled={!sig}>
          Confirm
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default UpdateSignatureConfirmationComponent;
