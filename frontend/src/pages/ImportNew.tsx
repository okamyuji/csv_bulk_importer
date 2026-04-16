import { useCallback, useState } from "react";
import { useDropzone } from "react-dropzone";
import { useNavigate } from "react-router-dom";
import { clsx } from "clsx";
import { api } from "../lib/api";

export function ImportNew() {
  const nav = useNavigate();
  const [file, setFile] = useState<File | null>(null);
  const [targetKind, setTargetKind] = useState<"sales_record" | "ledger_entry">(
    "sales_record",
  );
  const [uploadPct, setUploadPct] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const onDrop = useCallback((accepted: File[]) => {
    if (accepted[0]) setFile(accepted[0]);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: { "text/csv": [".csv"], "application/vnd.ms-excel": [".csv"] },
    maxFiles: 1,
  });

  async function submit() {
    if (!file) return;
    setSubmitting(true);
    setError(null);
    try {
      const res = await api.createImport(file, targetKind, (p) =>
        setUploadPct(p),
      );
      nav(`/imports/${res.data.id}`);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="space-y-6">
      <header>
        <h2 className="text-xl font-semibold">New CSV import</h2>
        <p className="text-sm text-slate-400">
          Upload a CSV up to several MB. Rows are streamed, chunked, and
          validated.
        </p>
      </header>

      <div className="flex gap-2 text-sm">
        {(["sales_record", "ledger_entry"] as const).map((k) => (
          <button
            key={k}
            onClick={() => setTargetKind(k)}
            className={clsx("rounded-full border px-3 py-1.5 transition", {
              "bg-sky-500 border-sky-500 text-slate-950": targetKind === k,
              "bg-transparent border-slate-700 text-slate-300 hover:border-slate-600":
                targetKind !== k,
            })}
          >
            {k}
          </button>
        ))}
      </div>

      <div
        {...getRootProps()}
        className={clsx(
          "cursor-pointer rounded-2xl border-2 border-dashed p-14 text-center transition",
          isDragActive
            ? "border-sky-400 bg-sky-500/5"
            : "border-slate-700 hover:border-slate-600",
        )}
      >
        <input {...getInputProps()} data-testid="file-input" />
        {file ? (
          <div>
            <p className="font-medium">{file.name}</p>
            <p className="text-xs text-slate-400">
              {(file.size / 1024).toFixed(1)} KB
            </p>
          </div>
        ) : (
          <p className="text-slate-400">
            Drag & drop a CSV, or click to pick one
          </p>
        )}
      </div>

      {uploadPct > 0 && uploadPct < 100 && (
        <p className="text-sm text-slate-400">
          Uploading: {uploadPct.toFixed(0)}%
        </p>
      )}
      {error && <p className="text-sm text-rose-400">{error}</p>}

      <button
        onClick={submit}
        disabled={!file || submitting}
        className="rounded-lg bg-sky-500 hover:bg-sky-400 disabled:opacity-50 text-slate-950 px-4 py-2 font-medium"
      >
        {submitting ? "Uploading…" : "Start import"}
      </button>
    </section>
  );
}
