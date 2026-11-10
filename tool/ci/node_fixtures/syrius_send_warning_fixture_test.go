package protocol

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/zenon-network/go-zenon/chain/nom"
)

func TestSyriusSendWarningFixturePreservesOriginalInsert(t *testing.T) {
	wantError := errors.New("original batch result")
	batch := make([]*nom.DetailedMomentum, 2)
	originalCalls := 0
	original := func(got []*nom.DetailedMomentum) (int, error) {
		originalCalls++
		if len(got) != len(batch) || &got[0] != &batch[0] {
			t.Fatal("the original callback received a different batch")
		}
		return 1, wantError
	}
	quit := make(chan struct{})
	defer close(quit)
	t.Setenv("SYRIUS_LAB_SEND_WARN_DIR", "")
	normal := newSyriusSendWarningFixture()
	if normal.tracksPeerAnnouncements() {
		t.Fatal("ordinary peer announcements changed")
	}
	plain := normal.wrapInsert(quit, original)
	if index, err := plain(batch); index != 1 || err != wantError {
		t.Fatal("ordinary insertion changed")
	}

	dir := t.TempDir()
	t.Setenv("SYRIUS_LAB_SEND_WARN_DIR", dir)
	fixture := newSyriusSendWarningFixture()
	owned := fixture.wrapInsert(quit, original)
	if fixture.tracksPeerAnnouncements() {
		t.Fatal("peer announcements changed before the observation window")
	}
	if index, err := owned(batch); index != 1 || err != wantError {
		t.Fatal("insertion before the observation window changed")
	}
	if err := os.Mkdir(filepath.Join(dir, "begin"), 0o700); err != nil {
		t.Fatal("could not create the test start marker")
	}
	if !fixture.tracksPeerAnnouncements() {
		t.Fatal("the fixture did not retain actual peer announcements")
	}
	if err := os.Mkdir(filepath.Join(dir, "release"), 0o700); err != nil {
		t.Fatal("could not create the test release marker")
	}
	if fixture.tracksPeerAnnouncements() {
		t.Fatal("peer announcements changed after release")
	}
	if index, err := owned(batch); index != 1 || err != wantError {
		t.Fatal("insertion after release changed")
	}
	if originalCalls != 3 {
		t.Fatal("unexpected original call count")
	}
}

func TestSyriusSendWarningFixtureRefusesInvalidMarkers(t *testing.T) {
	for _, name := range []string{"release", "begin"} {
		t.Run(name, func(t *testing.T) {
			dir := t.TempDir()
			t.Setenv("SYRIUS_LAB_SEND_WARN_DIR", dir)
			if name == "release" {
				if err := os.Mkdir(filepath.Join(dir, name), 0o700); err != nil {
					t.Fatal("could not create the test release marker")
				}
			} else if err := os.WriteFile(filepath.Join(dir, name), nil, 0o600); err != nil {
				t.Fatal("could not create the invalid test start marker")
			}
			original := func([]*nom.DetailedMomentum) (int, error) {
				t.Fatal("the invalid marker reached original insertion")
				return 0, nil
			}
			if _, err := newSyriusSendWarningFixture().wrapInsert(make(chan struct{}), original)(nil); err != errSyriusSendWarningScope {
				t.Fatal("the invalid marker was accepted")
			}
		})
	}
}

func TestSyriusSendWarningFixtureBoundsWaitAndHonorsShutdown(t *testing.T) {
	dir := t.TempDir()
	if err := os.Mkdir(filepath.Join(dir, "begin"), 0o700); err != nil {
		t.Fatal("could not create the test start marker")
	}
	owner, err := os.Lstat(dir)
	if err != nil {
		t.Fatal("could not observe the test owner")
	}
	deadline := time.Now().Add(25 * time.Millisecond)
	quit := make(chan struct{})
	if err := syriusWaitForRelease(quit, deadline, dir, owner); err != nil || time.Now().Before(deadline) {
		t.Fatal("the observation window ended before its bound")
	}
	fixture := &syriusSendWarningFixture{dir: dir, owner: owner}
	fixture.startOnce.Do(func() { fixture.until = deadline })
	if fixture.tracksPeerAnnouncements() {
		t.Fatal("peer announcements changed beyond the observation deadline")
	}
	close(quit)
	if err := syriusWaitForRelease(quit, time.Now().Add(time.Minute), dir, owner); err != errSyriusSendWarningClosed {
		t.Fatal("shutdown did not interrupt the observation window")
	}
}
