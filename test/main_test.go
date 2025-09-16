// -------------------------------------------------------
// Copyright (c) 2025 Arm Limited. All rights reserved.
//
// SPDX-License-Identifier: Apache-2.0
// -------------------------------------------------------

package main

import "testing"

func TestMain(t *testing.T) {
	// Example test
	got := "Hello, workflows-and-actions-collection!"
	want := "Hello, workflows-and-actions-collection!"
	if got != want {
		t.Errorf("got %q, want %q", got, want)
	}
}
