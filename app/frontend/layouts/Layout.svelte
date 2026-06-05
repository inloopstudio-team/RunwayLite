<script>
  import { page } from '@inertiajs/svelte';
  import { Toaster } from '$lib/components/shadcn/sonner/index.js';
  import { toast } from 'svelte-sonner';
  import Navbar from '$lib/components/navigation/navbar.svelte'; // Adjust the path as necessary
  import { ModeWatcher, setMode, resetMode, mode } from 'mode-watcher';

  let { children } = $props();
  let themeInitialized = false;

  $effect(() => {
    let flash = $page.props?.flash || {};

    flash.notice && toast.success(flash.notice);
    flash.alert && toast.error(flash.alert);
  });

  // Apply user's theme preference on initial load only
  $effect(() => {
    if (!themeInitialized) {
      const userTheme = $page.props?.user?.preferences?.theme || $page.props?.theme_preference;
      if (userTheme && userTheme !== 'system') {
        setMode(userTheme);
      } else if (userTheme === 'system') {
        resetMode();
      }
      themeInitialized = true;
    }
  });
</script>

<ModeWatcher />
<div class="bg-bg">
  <Navbar />
  <main>{@render children?.()}</main>
  <footer class="border-t py-4 px-6 text-center text-xs text-muted-foreground">
    For more advanced features, check out <a
      href="https://inloop.studio/runway"
      target="_blank"
      rel="noopener noreferrer"
      class="underline hover:text-foreground transition-colors">inloop.studio/runway</a>
  </footer>
  <Toaster />
</div>
