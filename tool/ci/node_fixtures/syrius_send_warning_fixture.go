package protocol

import (
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/zenon-network/go-zenon/chain/nom"
)

const syriusSendWarningWindow = 90 * time.Second

var errSyriusSendWarningScope = errors.New("isolated sync fixture scope refused")
var errSyriusSendWarningClosed = errors.New("isolated sync fixture closed")

type syriusLagInsert = func([]*nom.DetailedMomentum) (int, error)

type syriusSendWarningFixture struct {
	dir       string
	owner     os.FileInfo
	startOnce sync.Once
	until     time.Time
}

// Only the isolated RPC actor receives the owned signal directory.
func newSyriusSendWarningFixture() *syriusSendWarningFixture {
	dir := os.Getenv("SYRIUS_LAB_SEND_WARN_DIR")
	if dir == "" {
		return nil
	}
	fixture := &syriusSendWarningFixture{dir: dir}
	owner, err := os.Lstat(dir)
	if err == nil && filepath.IsAbs(dir) && filepath.Clean(dir) == dir &&
		owner.IsDir() && owner.Mode()&os.ModeSymlink == 0 {
		fixture.owner = owner
	}
	return fixture
}

func (fixture *syriusSendWarningFixture) active() (time.Time, bool, error) {
	if fixture == nil {
		return time.Time{}, false, nil
	}
	if fixture.owner == nil {
		return time.Time{}, false, errSyriusSendWarningScope
	}
	begin, release, err := syriusLagMarkers(fixture.dir, fixture.owner)
	if err != nil || !begin || release {
		return time.Time{}, false, err
	}
	fixture.startOnce.Do(func() {
		fixture.until = time.Now().Add(syriusSendWarningWindow)
	})
	return fixture.until, time.Now().Before(fixture.until), nil
}

func (fixture *syriusSendWarningFixture) tracksPeerAnnouncements() bool {
	_, active, err := fixture.active()
	return err == nil && active
}

func (fixture *syriusSendWarningFixture) wrapInsert(quit <-chan struct{}, insert syriusLagInsert) syriusLagInsert {
	if fixture == nil {
		return insert
	}
	return func(batch []*nom.DetailedMomentum) (int, error) {
		until, active, err := fixture.active()
		if err != nil {
			return 0, err
		}
		if active {
			if err := syriusWaitForRelease(quit, until, fixture.dir, fixture.owner); err != nil {
				return 0, err
			}
		}
		select {
		case <-quit:
			return 0, errSyriusSendWarningClosed
		default:
			return insert(batch)
		}
	}
}

func syriusLagMarkers(dir string, owner os.FileInfo) (begin, release bool, err error) {
	current, err := os.Lstat(dir)
	if err != nil || !current.IsDir() || !os.SameFile(owner, current) {
		return false, false, errSyriusSendWarningScope
	}
	release, err = syriusLagMarker(filepath.Join(dir, "release"))
	if err != nil {
		return false, false, err
	}
	begin, err = syriusLagMarker(filepath.Join(dir, "begin"))
	if err != nil || release && !begin {
		return false, false, errSyriusSendWarningScope
	}
	return begin, release, nil
}

func syriusLagMarker(path string) (bool, error) {
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return false, errSyriusSendWarningScope
	}
	return true, nil
}

func syriusWaitForRelease(quit <-chan struct{}, until time.Time, dir string, owner os.FileInfo) error {
	timer := time.NewTimer(time.Until(until))
	defer timer.Stop()
	tick := time.NewTicker(500 * time.Millisecond)
	defer tick.Stop()
	for {
		select {
		case <-quit:
			return errSyriusSendWarningClosed
		case <-timer.C:
			return nil
		case <-tick.C:
			begin, release, err := syriusLagMarkers(dir, owner)
			if err != nil || !begin {
				return errSyriusSendWarningScope
			}
			if release {
				return nil
			}
		}
	}
}
