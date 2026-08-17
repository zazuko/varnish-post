import { execFile } from "node:child_process";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const cwd = dirname(fileURLToPath(import.meta.url));

// Pin the Compose project name instead of letting it default to the directory
// name ("test"), which is generic enough to collide with unrelated stacks.
const PROJECT = "varnish-post-test";

// Image builds are chatty, so give the child process room for their output.
const MAX_BUFFER = 32 * 1024 * 1024;

const compose = (args) =>
  execFileAsync("docker", ["compose", "--project-name", PROJECT, ...args], {
    cwd,
    maxBuffer: MAX_BUFFER,
  });

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Resolve the host address Compose assigned to a service port.
 *
 * The compose file publishes container ports on dynamically allocated host
 * ports, so the suite never fights whatever else is already listening locally.
 */
const serviceUrl = async (service, containerPort) => {
  const { stdout } = await compose(["port", service, String(containerPort)]);

  // `docker compose port` can print both an IPv4 and an IPv6 mapping.
  const mapping = stdout.trim().split("\n")[0];
  const port = mapping.split(":").pop();

  if (!port) {
    throw new Error(
      `Could not determine the host port for ${service}:${containerPort} (got "${stdout.trim()}")`,
    );
  }

  return `http://127.0.0.1:${port}`;
};

/** Poll an endpoint until it answers, so tests never race the container boot. */
const waitForHttp = async (url, { timeoutMs = 120_000, intervalMs = 250 } = {}) => {
  const deadline = Date.now() + timeoutMs;
  let lastError;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(2000) });
      if (response.ok) {
        return;
      }
      lastError = new Error(`responded with HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }

    await sleep(intervalMs);
  }

  throw new Error(`Timed out waiting for ${url} to become ready: ${lastError?.message}`);
};

const teardown = async () => {
  await compose(["down", "--volumes"]);
};

export async function globalSetup() {
  try {
    await compose(["up", "--detach", "--build", "--wait"]);
  } catch (error) {
    // The shell script this replaced ignored the exit code here, so a failure
    // to bind the published ports left every later request hitting whatever
    // else happened to be listening -- and the suite still reported success.
    const details = error.stderr?.trim() || error.message;

    // A partially started stack still has containers to clean up.
    await teardown().catch(() => {});

    throw new Error(`Failed to start the Docker stack:\n${details}`, { cause: error });
  }

  try {
    const [backendUrl, varnishUrl] = await Promise.all([
      serviceUrl("backend", 8080),
      serviceUrl("varnish", 80),
    ]);

    await Promise.all([waitForHttp(backendUrl), waitForHttp(varnishUrl)]);

    // Test files run in child processes and inherit this environment.
    process.env.BACKEND_URL = backendUrl;
    process.env.VARNISH_URL = varnishUrl;
  } catch (error) {
    await teardown();
    throw error;
  }
}

export async function globalTeardown() {
  await teardown();
}
