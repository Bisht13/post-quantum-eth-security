import { CircularProgress, Container } from '@mui/material';
import React, { ReactElement, useCallback, useState } from 'react';
import {
  AccountImplementations,
  ActiveAccountImplementation,
} from '../../../App/constants';
import {
  useBackgroundDispatch,
  useBackgroundSelector,
} from '../../../App/hooks';
import { getActiveAccount } from '../../../Background/redux-slices/selectors/accountSelectors';
import {
  selectCurrentPendingModifiedSendTransactionRequest,
  selectCurrentPendingSendTransactionRequest,
  selectCurrentPendingSendTransactionUserOp,
} from '../../../Background/redux-slices/selectors/transactionsSelectors';
import {
  createUnsignedUserOp,
  rejectTransaction,
  sendTransaction,
} from '../../../Background/redux-slices/transactions';
import { EthersTransactionRequest } from '../../../Background/services/types';
import { setModifyTransactionRequest } from '../../../Background/redux-slices/transactions';

const SignTransactionComponent =
  AccountImplementations[ActiveAccountImplementation].Transaction;
var Signature: string;
const SignTransactionRequest = (): ReactElement => {
  const [stage, setStage] = useState<{
    stage:
      | 'pre-transaction-confirmation'
      | 'transaction-confirmation'
      | 'update-signature-confirmation'
      | 'post-transaction-confirmation'
      | 'hash-generation';
    context?: any;
  }>({
    stage: 'pre-transaction-confirmation',
  });

  const backgroundDispatch = useBackgroundDispatch();
  const activeAccount = useBackgroundSelector(getActiveAccount);

  const sendTransactionRequest = useBackgroundSelector(
    selectCurrentPendingSendTransactionRequest
  );

  const sendModiefiedTransactionRequest = useBackgroundSelector(
    selectCurrentPendingModifiedSendTransactionRequest
  );

  const pendingUserOp = useBackgroundSelector(
    selectCurrentPendingSendTransactionUserOp
  );


  const handleSignatureInput = (input: string) => {
    Signature = input;
  };


  const onSend = useCallback(
    async (context?: any) => {
      if (activeAccount)
        await backgroundDispatch(
          sendTransaction({
            address: activeAccount,
            signature: Signature,
            context,
          })
        );
      window.close();
    },
    [activeAccount, backgroundDispatch]
  );

  const onCompletePreTransactionConfirmation = useCallback(
    async (modifiedTransaction?: EthersTransactionRequest, context?: any) => {
      if (!activeAccount) return;
      backgroundDispatch(
        createUnsignedUserOp({ address: activeAccount, context })
      );
      backgroundDispatch(
        setModifyTransactionRequest(
          modifiedTransaction || sendTransactionRequest.transactionRequest
        )
      );
      setStage({
        stage: 'hash-generation',
        context,
      });
    },
    [
      activeAccount,
      backgroundDispatch,
      sendTransactionRequest.transactionRequest,
    ]
  );
  const onCompleteHashGeneration = useCallback(
    async (context?: any) => {
      setStage({
        stage: 'update-signature-confirmation',
        context,
      });
    },
    []
  );
  const onCompleteUpdateSignatureConfirmation = useCallback(
    async (context?: any) => {
      setStage({
        stage: 'transaction-confirmation',
        context,
      });
    },
    []
  );

  const onCompleteTransactionConfirmation = useCallback(
    async (context?: any) => {
      setStage({
        stage: 'post-transaction-confirmation',
        context,
      });
    },
    []
  );
  
  const onCompletePostTransactionConfirmation = useCallback(
    async (context?: any) => {
      if (activeAccount) {
        onSend(context);
      }
    },
    [activeAccount, onSend]
  );

  const onReject = useCallback(async () => {
    if (activeAccount)
      await backgroundDispatch(rejectTransaction(activeAccount));
    window.close();
  }, [backgroundDispatch, activeAccount]);

  switch (stage.stage) {
    case 'pre-transaction-confirmation':
      if (SignTransactionComponent?.PreTransactionConfirmation) {
        return (
          <SignTransactionComponent.PreTransactionConfirmation
            onReject={onReject}
            // FIXME: What if sendTransactionRequest.transactionRequest is undefined?
            // (If it can't be undefined, why does the type say it can?)
            transaction={sendTransactionRequest.transactionRequest!}
            onComplete={onCompletePreTransactionConfirmation}
          />
        );
      }

      onCompletePreTransactionConfirmation(
        sendTransactionRequest.transactionRequest,
        {}
      );

      return <></>;
    case 'transaction-confirmation':
      return SignTransactionComponent?.TransactionConfirmation &&
        sendModiefiedTransactionRequest.transactionRequest &&
        pendingUserOp ? (
        <SignTransactionComponent.TransactionConfirmation
          context={stage.context}
          onReject={onReject}
          userOp={pendingUserOp}
          transaction={sendModiefiedTransactionRequest.transactionRequest}
          onComplete={onCompleteTransactionConfirmation}
        />
      ) : (
        <Container
          sx={{
            height: '100vh',
            justifyContent: 'center',
            alignItems: 'center',
            display: 'flex',
          }}
        >
          <CircularProgress />
        </Container>
      );
    case 'hash-generation':
      return SignTransactionComponent?.HashGenerationConfirmation &&
      sendModiefiedTransactionRequest.transactionRequest &&
      pendingUserOp ? (
      <SignTransactionComponent.HashGenerationConfirmation
        context={stage.context}
        userOp={pendingUserOp}
        onComplete={onCompleteHashGeneration}
      />) : (
        <></>
      );
    case 'update-signature-confirmation':
      //write signature to disk uding some package
      return SignTransactionComponent?.UpdateSignatureConfirmation &&
      sendModiefiedTransactionRequest.transactionRequest &&
      pendingUserOp ? (
      <SignTransactionComponent.UpdateSignatureConfirmation
        updateSignature={handleSignatureInput}
        context={stage.context}
        userOp={pendingUserOp}
        onComplete={onCompleteUpdateSignatureConfirmation}
      />) : (
        <></>
      );
    case 'post-transaction-confirmation':
      if (
        SignTransactionComponent?.PostTransactionConfirmation &&
        pendingUserOp
      ) {
        return (
          <SignTransactionComponent.PostTransactionConfirmation
            context={stage.context}
            onReject={onReject}
            userOp={pendingUserOp}
            // FIXME: What if sendTransactionRequest.transactionRequest is undefined?
            // (If it can't be undefined, why does the type say it can?)
            transaction={sendModiefiedTransactionRequest.transactionRequest!}
            onComplete={onCompletePostTransactionConfirmation}
          />
        );
      }

      return <></>;
  }
};

export default SignTransactionRequest;
