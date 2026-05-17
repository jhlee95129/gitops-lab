export default async function Home() {
  let version = "unknown";
  try {
    const res = await fetch(`${process.env.API_URL}/api/version`, {
      cache: "no-store",
    });
    const data = await res.json();
    version = data.version;
  } catch {
    version = "unavailable";
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 font-sans dark:bg-black">
      <main className="text-center">
        <h1 className="text-3xl font-semibold text-black dark:text-zinc-50">
          gitops-lab
        </h1>
        <p className="mt-4 text-lg text-zinc-600 dark:text-zinc-400">
          API version: {version}
        </p>
      </main>
    </div>
  );
}
