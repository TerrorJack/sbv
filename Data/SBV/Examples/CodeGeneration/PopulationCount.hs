-----------------------------------------------------------------------------
-- |
-- Module      :  Data.SBV.Examples.CodeGeneration.PopulationCount
-- Copyright   :  (c) Levent Erkok
-- License     :  BSD3
-- Maintainer  :  erkokl@gmail.com
-- Stability   :  experimental
--
-- Computing population-counts (number of set bits) and automatically
-- generating C code.
-----------------------------------------------------------------------------

module Data.SBV.Examples.CodeGeneration.PopulationCount where

import Data.SBV
import Data.SBV.Tools.CodeGen

-----------------------------------------------------------------------------
-- * Reference: Slow but /obviously/ correct
-----------------------------------------------------------------------------

-- | Given a 64-bit quantity, the simplest (and obvious) way to count the
-- number of bits that are set in it is to simply walk through all the bits
-- and add 1 to a running count. This is slow, as it requires 64 iterations,
-- but is simple and easy to convince yourself that it is correct. For instance:
--
-- >>> popCountSlow 0x0123456789ABCDEF
-- 32 :: SWord8
popCountSlow :: SWord64 -> SWord8
popCountSlow inp = go inp 0 0
  where go :: SWord64 -> Int -> SWord8 -> SWord8
        go _ 64 c = c
        go x i  c = go (x `shiftR` 1) (i+1) (ite (x .&. 1 .== 1) (c+1) c)

-----------------------------------------------------------------------------
-- * Faster: Using a look-up table
-----------------------------------------------------------------------------

-- | Faster version. This is essentially the same algorithm, except we
-- go 8 bits at a time instead of one by one, by using a precomputed table
-- of population-count values for each byte. This algorithm /loops/ only
-- 8 times, and hence is at least 8 times more efficient.
popCountFast :: SWord64 -> SWord8
popCountFast inp = go inp 0 0
  where go :: SWord64 -> Int -> SWord8 -> SWord8
        go _ 8 c = c
        go x i c = go (x `shiftR` 8) (i+1) (c + select pop8 0 (x .&. 0xff))

-- | Look-up table, containing population counts for all possible 8-bit
-- value, from 0 to 255. Note that we do not \"hard-code\" the values, but
-- merely use the slow version to compute them.
pop8 :: [SWord8]
pop8 = map popCountSlow [0 .. 255]

-----------------------------------------------------------------------------
-- * Verification
-----------------------------------------------------------------------------

{- $VerificationIntro
We prove that `popCountFast` and `popCountSlow` are functionally equivalent.
This is essential as we will automatically generate C code from `popCountFast`,
and we would like to make sure that the fast version is correct with
respect to the slower reference version.
-}

-- | States the correctness of faster population-count algorithm, with respect
-- to the reference slow version. Turns out Z3's default solver is rather slow
-- for this one, but there's a magic incantation to make it go fast.
-- See <https://github.com/Z3Prover/z3/issues/1150> for details.
--
-- >>> let cmd = "(check-sat-using (then (using-params ackermannize_bv :div0_ackermann_limit 1000000) simplify bit-blast sat))"
-- >>> proveWith z3{satCmd = cmd} fastPopCountIsCorrect
-- Q.E.D.
fastPopCountIsCorrect :: SWord64 -> SBool
fastPopCountIsCorrect x = popCountFast x .== popCountSlow x

-----------------------------------------------------------------------------
-- * Code generation
-----------------------------------------------------------------------------

-- | Not only we can prove that faster version is correct, but we can also automatically
-- generate C code to compute population-counts for us. This action will generate all the
-- C files that you will need, including a driver program for test purposes.
--
-- Below is the generated header file for `popCountFast`:
--
-- >>> genPopCountInC
-- == BEGIN: "Makefile" ================
-- # Makefile for popCount. Automatically generated by SBV. Do not edit!
-- <BLANKLINE>
-- # include any user-defined .mk file in the current directory.
-- -include *.mk
-- <BLANKLINE>
-- CC?=gcc
-- CCFLAGS?=-Wall -O3 -DNDEBUG -fomit-frame-pointer
-- <BLANKLINE>
-- all: popCount_driver
-- <BLANKLINE>
-- popCount.o: popCount.c popCount.h
-- 	${CC} ${CCFLAGS} -c $< -o $@
-- <BLANKLINE>
-- popCount_driver.o: popCount_driver.c
-- 	${CC} ${CCFLAGS} -c $< -o $@
-- <BLANKLINE>
-- popCount_driver: popCount.o popCount_driver.o
-- 	${CC} ${CCFLAGS} $^ -o $@
-- <BLANKLINE>
-- clean:
-- 	rm -f *.o
-- <BLANKLINE>
-- veryclean: clean
-- 	rm -f popCount_driver
-- == END: "Makefile" ==================
-- == BEGIN: "popCount.h" ================
-- /* Header file for popCount. Automatically generated by SBV. Do not edit! */
-- <BLANKLINE>
-- #ifndef __popCount__HEADER_INCLUDED__
-- #define __popCount__HEADER_INCLUDED__
-- <BLANKLINE>
-- #include <stdio.h>
-- #include <stdlib.h>
-- #include <inttypes.h>
-- #include <stdint.h>
-- #include <stdbool.h>
-- #include <string.h>
-- #include <math.h>
-- <BLANKLINE>
-- /* The boolean type */
-- typedef bool SBool;
-- <BLANKLINE>
-- /* The float type */
-- typedef float SFloat;
-- <BLANKLINE>
-- /* The double type */
-- typedef double SDouble;
-- <BLANKLINE>
-- /* Unsigned bit-vectors */
-- typedef uint8_t  SWord8;
-- typedef uint16_t SWord16;
-- typedef uint32_t SWord32;
-- typedef uint64_t SWord64;
-- <BLANKLINE>
-- /* Signed bit-vectors */
-- typedef int8_t  SInt8;
-- typedef int16_t SInt16;
-- typedef int32_t SInt32;
-- typedef int64_t SInt64;
-- <BLANKLINE>
-- /* Entry point prototype: */
-- SWord8 popCount(const SWord64 x);
-- <BLANKLINE>
-- #endif /* __popCount__HEADER_INCLUDED__ */
-- == END: "popCount.h" ==================
-- == BEGIN: "popCount_driver.c" ================
-- /* Example driver program for popCount. */
-- /* Automatically generated by SBV. Edit as you see fit! */
-- <BLANKLINE>
-- #include <stdio.h>
-- #include "popCount.h"
-- <BLANKLINE>
-- int main(void)
-- {
--   const SWord8 __result = popCount(0x1b02e143e4f0e0e5ULL);
-- <BLANKLINE>
--   printf("popCount(0x1b02e143e4f0e0e5ULL) = %"PRIu8"\n", __result);
-- <BLANKLINE>
--   return 0;
-- }
-- == END: "popCount_driver.c" ==================
-- == BEGIN: "popCount.c" ================
-- /* File: "popCount.c". Automatically generated by SBV. Do not edit! */
-- <BLANKLINE>
-- #include "popCount.h"
-- <BLANKLINE>
-- SWord8 popCount(const SWord64 x)
-- {
--   const SWord64 s0 = x;
--   static const SWord8 table0[] = {
--       0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4, 1, 2, 2, 3, 2, 3,
--       3, 4, 2, 3, 3, 4, 3, 4, 4, 5, 1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4,
--       3, 4, 4, 5, 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 1, 2,
--       2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5, 2, 3, 3, 4, 3, 4, 4, 5,
--       3, 4, 4, 5, 4, 5, 5, 6, 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5,
--       5, 6, 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, 1, 2, 2, 3,
--       2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5, 2, 3, 3, 4, 3, 4, 4, 5, 3, 4,
--       4, 5, 4, 5, 5, 6, 2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
--       3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, 2, 3, 3, 4, 3, 4,
--       4, 5, 3, 4, 4, 5, 4, 5, 5, 6, 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6,
--       5, 6, 6, 7, 3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7, 4, 5,
--       5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8
--   };
--   const SWord64 s11 = s0 & 0x00000000000000ffULL;
--   const SWord8  s12 = table0[s11];
--   const SWord64 s14 = s0 >> 8;
--   const SWord64 s15 = 0x00000000000000ffULL & s14;
--   const SWord8  s16 = table0[s15];
--   const SWord8  s17 = s12 + s16;
--   const SWord64 s18 = s14 >> 8;
--   const SWord64 s19 = 0x00000000000000ffULL & s18;
--   const SWord8  s20 = table0[s19];
--   const SWord8  s21 = s17 + s20;
--   const SWord64 s22 = s18 >> 8;
--   const SWord64 s23 = 0x00000000000000ffULL & s22;
--   const SWord8  s24 = table0[s23];
--   const SWord8  s25 = s21 + s24;
--   const SWord64 s26 = s22 >> 8;
--   const SWord64 s27 = 0x00000000000000ffULL & s26;
--   const SWord8  s28 = table0[s27];
--   const SWord8  s29 = s25 + s28;
--   const SWord64 s30 = s26 >> 8;
--   const SWord64 s31 = 0x00000000000000ffULL & s30;
--   const SWord8  s32 = table0[s31];
--   const SWord8  s33 = s29 + s32;
--   const SWord64 s34 = s30 >> 8;
--   const SWord64 s35 = 0x00000000000000ffULL & s34;
--   const SWord8  s36 = table0[s35];
--   const SWord8  s37 = s33 + s36;
--   const SWord64 s38 = s34 >> 8;
--   const SWord64 s39 = 0x00000000000000ffULL & s38;
--   const SWord8  s40 = table0[s39];
--   const SWord8  s41 = s37 + s40;
-- <BLANKLINE>
--   return s41;
-- }
-- == END: "popCount.c" ==================
genPopCountInC :: IO ()
genPopCountInC = compileToC Nothing "popCount" $ do
        cgSetDriverValues [0x1b02e143e4f0e0e5]  -- remove this line to get a random test value
        x <- cgInput "x"
        cgReturn $ popCountFast x