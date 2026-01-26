// Move Bastion tabs to popup windows (preserves session!)
const BASTION_PATTERN = 'https://bst-e021affb-8ee4-460a-be3f-f153e775d3cd.bastion.azure.com/';

let processingTabs = new Set();
let movedTabs = new Set(); // Track tabs we've already moved

// When a tab is updated with Bastion URL
chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  // Only process when status is complete (fully loaded)
  if (changeInfo.status !== 'complete') {
    return;
  }

  // Only process Bastion URLs
  if (!tab.url || !tab.url.startsWith(BASTION_PATTERN)) {
    return;
  }

  // Skip if already processed this tab
  if (movedTabs.has(tabId)) {
    console.log('Tab already moved, skipping');
    return;
  }

  // Skip if already processing
  if (processingTabs.has(tabId)) {
    return;
  }

  processingTabs.add(tabId);

  try {
    // Get current window info
    const window = await chrome.windows.get(tab.windowId);

    // If already in a popup, don't process
    if (window.type === 'popup') {
      console.log('Already in popup window, skipping');
      movedTabs.add(tabId);
      processingTabs.delete(tabId);
      return;
    }

    console.log('Moving Bastion tab to popup window (preserving session)');

    // Create a new popup window by moving the tab directly
    const newWindow = await chrome.windows.create({
      tabId: tabId,
      type: 'popup',
      focused: true,
      state: 'maximized'
    });

    // Mark this tab as moved
    movedTabs.add(tabId);

    console.log('Tab moved to popup successfully');

  } catch (error) {
    console.error('Error moving tab to popup:', error);
  } finally {
    processingTabs.delete(tabId);
  }
});

// Clean up moved tabs tracking when tabs are closed
chrome.tabs.onRemoved.addListener((tabId) => {
  movedTabs.delete(tabId);
  processingTabs.delete(tabId);
});

console.log('Azure Bastion App Mode v2.2: Background script loaded');
