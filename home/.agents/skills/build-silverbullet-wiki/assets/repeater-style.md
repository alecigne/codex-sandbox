```space-style
.repeater {
  position: relative;
  margin: 0.9rem 0 0.75rem;
  padding: 1.65rem 1.1rem 0.25rem;
  border: 1px solid color-mix(in srgb, var(--ui-accent-color) 35%, transparent);
  border-left: 0.3rem solid var(--ui-accent-color);
  border-radius: 0.6rem;
  background: color-mix(in srgb, var(--ui-accent-color) 8%, transparent);
  box-shadow: 0 0.2rem 0.8rem rgb(0 0 0 / 8%);
}

.repeater:before {
  content: "SRS";
  position: absolute;
  top: 0.55rem;
  left: 1rem;
  padding: 0.15rem 0.55rem;
  border-radius: 999px;
  background: var(--ui-accent-color);
  color: white;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.1em;
}

.repeater > :first-child {
  margin-top: 0;
}

.repeater > :last-child {
  margin-bottom: 0;
}

.repeater p,
.repeater h2 {
  border: 0;
  font-size: 1rem;
  font-weight: normal;
  line-height: 1.55;
  margin-bottom: 0.6rem;
  white-space: pre-line;
}

.repeater hr:last-child {
  display: none;
}
```
