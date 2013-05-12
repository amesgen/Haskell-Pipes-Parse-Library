{-| This module exposes internal implementation details that might change in the
    future.  I only expose this so that people can write high-efficiency parsing
    primitives not implementable in terms of existing primitives.  My own
    benchmarks show that you almost always get equally fast performance using
    'drawMay', sometimes even faster, so you probably never need this module.
-}

{-# LANGUAGE PolymorphicComponents #-}

module Control.Proxy.Parse.Internal (
    -- * Parsing proxy transformer
    ParseT(..),
    ) where

import Control.Applicative (Applicative(pure, (<*>)), Alternative(empty, (<|>)))
import Control.Monad (MonadPlus(mzero, mplus))
import Control.Monad.IO.Class(MonadIO(liftIO))
import Control.Monad.Morph (MFunctor(hoist))
import Control.Monad.Trans.Class(MonadTrans(lift))
import qualified Control.Proxy as P
import qualified Control.Proxy.Trans.Maybe as M
import qualified Control.Proxy.Trans.State as S

-- | The 'ParseP' proxy transformer stores parsing leftovers
newtype ParseT s a m b = ParseT
    { runParseT
        :: forall p y' y
        .  P.Proxy p
        => M.MaybeP (S.StateP s p) () (Maybe a) y' y m b
    }

-- Deriving Functor
instance (Monad m) => Functor (ParseT s a m) where
    fmap f p = ParseT (fmap f (runParseT p))

-- Deriving Applicative
instance (Monad m) => Applicative (ParseT s a m) where
    pure r  = ParseT (pure r)
    f <*> x = ParseT (runParseT f <*> runParseT x)

-- Deriving Monad
instance (Monad m) => Monad (ParseT s a m) where
    return r = ParseT (P.return_P r)
    m >>= f  = ParseT (runParseT m >>= \r -> runParseT (f r))

-- Deriving Alternative
instance (Monad m) => Alternative (ParseT s a m) where
    empty     = ParseT empty
    p1 <|> p2 = ParseT (runParseT p1 <|> runParseT p2)

-- Deriving MonadPlus
instance (Monad m) => MonadPlus (ParseT s a m) where
    mzero       = ParseT mzero
    mplus p1 p2 = ParseT (mplus (runParseT p1) (runParseT p2))

-- Deriving MonadTrans
instance MonadTrans (ParseT s a) where
    lift m = ParseT (lift m)

-- Deriving MFunctor
instance P.MFunctor (ParseT s a) where
    hoist nat p = ParseT (hoist nat (runParseT p))

-- Deriving MonadIO
instance (MonadIO m) => MonadIO (ParseT s a m) where
    liftIO io = ParseT (liftIO io)

{-
{-| Evaluate a non-backtracking parser, returning the result or failing with a
    'ParseFailure' exception.
 -}
runParseP :: (Monad m, P.Proxy p) => ParseP i p a' a b' b m r -> p a' a b' b m r
runParseP p = S.evalStateP [] (unParseP p)
{-# INLINABLE runParseP #-}

{-| Evaluate a non-backtracking parser \'@K@\'leisli arrow, returning the result
    or failing with a 'ParseFailure' exception.
 -}
runParseK
    :: (Monad m, P.Proxy p)
    => (q -> ParseP i p a' a b' b m r) -> (q -> p a' a b' b m r)
runParseK k q = runParseP (k q)
{-# INLINABLE runParseK #-}
-}
