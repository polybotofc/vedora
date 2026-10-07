using System.Diagnostics;
using System.Text;

namespace Vedora.RccServiceArbiter.Processes;

public sealed class RccProcessLauncher : IRccProcessLauncher
{
    public IManagedProcess Start(string fileName, string arguments, string? workingDirectory = null)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo(fileName, arguments)
            {
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                WorkingDirectory = string.IsNullOrWhiteSpace(workingDirectory)
                    ? AppContext.BaseDirectory
                    : workingDirectory,
            },
        };

        var output = new StringBuilder();
        var outputGate = new object();
        void Capture(object _, DataReceivedEventArgs args)
        {
            if (string.IsNullOrEmpty(args.Data)) return;
            lock (outputGate)
            {
                if (output.Length < 64 * 1024) output.AppendLine(args.Data);
            }
        }

        process.OutputDataReceived += Capture;
        process.ErrorDataReceived += Capture;

        if (!process.Start())
        {
            process.Dispose();
            throw new InvalidOperationException($"Failed to start process {fileName}");
        }

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        return new ManagedProcess(process, output, outputGate);
    }

    private sealed class ManagedProcess : IManagedProcess
    {
        private readonly Process _process;
        private readonly StringBuilder _output;
        private readonly object _outputGate;

        public ManagedProcess(Process process, StringBuilder output, object outputGate)
        {
            _process = process;
            _output = output;
            _outputGate = outputGate;
        }

        public int? Id => _process.Id;

        public bool HasExited
        {
            get
            {
                try
                {
                    return _process.HasExited;
                }
                catch (InvalidOperationException)
                {
                    return true;
                }
            }
        }

        public void KillTree()
        {
            try
            {
                _process.Kill(entireProcessTree: true);
                _process.WaitForExit(5000);
            }
            catch (InvalidOperationException)
            {
            }
        }

        public bool TryGetOutput(out string output)
        {
            lock (_outputGate)
            {
                output = _output.ToString().Trim();
                return output.Length > 0;
            }
        }

        public void Dispose()
        {
            _process.Dispose();
        }
    }
}
