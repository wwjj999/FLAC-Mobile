package gobackend

import "testing"

func TestItemProgressPreparingAndDownloadingStatuses(t *testing.T) {
	const itemID = "progress-phase-item"
	RemoveItemProgress(itemID)
	defer RemoveItemProgress(itemID)

	StartItemProgress(itemID)
	SetItemPreparing(itemID)

	if item := multiProgress.Items[itemID]; item == nil {
		t.Fatal("expected item progress entry to exist")
	} else {
		if item.Status != itemProgressStatusPreparing {
			t.Fatalf("status = %q, want %q", item.Status, itemProgressStatusPreparing)
		}
		if item.Progress != 0 {
			t.Fatalf("progress = %v, want 0", item.Progress)
		}
	}

	SetItemProgress(itemID, 0.37, 0, 0)
	if item := multiProgress.Items[itemID]; item == nil {
		t.Fatal("expected item progress entry to exist after update")
	} else if item.Status != itemProgressStatusPreparing {
		t.Fatalf("status after progress update = %q, want %q", item.Status, itemProgressStatusPreparing)
	}

	SetItemDownloading(itemID)
	if item := multiProgress.Items[itemID]; item == nil {
		t.Fatal("expected item progress entry to exist after downloading status")
	} else if item.Status != itemProgressStatusDownloading {
		t.Fatalf("status after download start = %q, want %q", item.Status, itemProgressStatusDownloading)
	}
}

func TestItemProgressFinalizingAndCompletedStatuses(t *testing.T) {
	const itemID = "progress-finalizing-item"
	RemoveItemProgress(itemID)
	defer RemoveItemProgress(itemID)

	StartItemProgress(itemID)
	SetItemFinalizing(itemID)

	if item := multiProgress.Items[itemID]; item == nil {
		t.Fatal("expected item progress entry to exist")
	} else if item.Status != itemProgressStatusFinalizing {
		t.Fatalf("status = %q, want %q", item.Status, itemProgressStatusFinalizing)
	}

	CompleteItemProgress(itemID)
	if item := multiProgress.Items[itemID]; item == nil {
		t.Fatal("expected item progress entry to exist after completion")
	} else if item.Status != itemProgressStatusCompleted {
		t.Fatalf("status = %q, want %q", item.Status, itemProgressStatusCompleted)
	}
}
